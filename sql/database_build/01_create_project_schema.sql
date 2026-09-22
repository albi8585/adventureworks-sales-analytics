/*
===============================================================================
 AdventureWorks Sales Analytics
 01 - CREATE PROJECT SCHEMA
 Clean / reproducible GitHub version
===============================================================================

Purpose:
- Create the final relational structure used by the AdventureWorks analytics
  project inside the custom `project` schema.
- Keep the original AdventureWorks tables unchanged and use them only as source
  tables for the initial load and subsequent temporal transformations.
- Define all columns directly in their final form so that no development-time
  ALTER TABLE operations are required later.
- Create the main primary-key and foreign-key relationships needed to preserve
  referential integrity between dimensions, order tables and historical tables.
- Create the staging and snapshot tables required by the Action Monitoring workflow.

Execution order:
  1) 01_create_project_schema.sql
  2) 02_load_initial_data.sql
  3) 03_post_load_transformations.sql

Important:
- This script creates structures only; it does not load any data.
- `modified_date` / `Modified_Date` fields belong to the project layer and are
  populated by the load/transformation scripts.
===============================================================================
*/

USE AdventureWorks2022;
GO


/* ---------------------------------------------------------------------------
   PROJECT SCHEMA

   Create the custom schema only when it does not already exist.
--------------------------------------------------------------------------- */
IF SCHEMA_ID('project') IS NULL
    EXEC('CREATE SCHEMA project');
GO


/* ---------------------------------------------------------------------------
   PRODUCT CATEGORY

   Top level of the product hierarchy used by the Power BI model.
--------------------------------------------------------------------------- */
CREATE TABLE project.ProductCategory (
    ProductCategoryID int NOT NULL,
    Name nvarchar(50) NOT NULL,
    modified_date date NULL,

    CONSTRAINT PK_ProductCategory
        PRIMARY KEY (ProductCategoryID)
);
GO


/* ---------------------------------------------------------------------------
   PRODUCT SUBCATEGORY

   Second level of the product hierarchy. Every subcategory belongs to one
   ProductCategory.
--------------------------------------------------------------------------- */
CREATE TABLE project.ProductSubCategory (
    ProductSubcategoryID int NOT NULL,
    ProductCategoryID int NOT NULL,
    Name nvarchar(50) NOT NULL,
    modified_date date NULL,

    CONSTRAINT PK_ProductSubCategory
        PRIMARY KEY (ProductSubcategoryID),

    CONSTRAINT FK_SubCategory_Category
        FOREIGN KEY (ProductCategoryID)
        REFERENCES project.ProductCategory (ProductCategoryID)
);
GO


/* ---------------------------------------------------------------------------
   PRODUCT

   Project copy of the product master data used by sales-detail and historical
   cost/price tables.

   SafetyStockLevel, ReorderPoint, StandardCost and ListPrice are stored here as
   current product attributes, while their historical evolution is retained in
   ProductCostHistory and ProductListPriceHistory.
--------------------------------------------------------------------------- */
CREATE TABLE project.Product (
    ProductID int NOT NULL,
    Name nvarchar(50) NOT NULL,
    DaysToManufacture int NOT NULL,
    ProductSubcategoryID int NULL,
    SafetyStockLevel int NOT NULL,
    ReorderPoint int NOT NULL,
    StandardCost money NOT NULL,
    ListPrice money NOT NULL,
    modified_date date NULL,

    CONSTRAINT PK_Product
        PRIMARY KEY (ProductID),

    CONSTRAINT FK_Product_SubCategory
        FOREIGN KEY (ProductSubcategoryID)
        REFERENCES project.ProductSubCategory (ProductSubcategoryID)
);
GO


/* ---------------------------------------------------------------------------
   SALES TERRITORY

   Geographic sales dimension used for region/country performance analysis.
--------------------------------------------------------------------------- */
CREATE TABLE project.Territory (
    TerritoryID int NOT NULL,
    Name nvarchar(50) NOT NULL,
    [Group] nvarchar(50) NOT NULL,
    modified_date date NULL,

    CONSTRAINT PK_Territory
        PRIMARY KEY (TerritoryID)
);
GO


/* ---------------------------------------------------------------------------
   SALES PERSON

   Sales-person master data. TerritoryID is nullable because not every source
   sales person is necessarily assigned to a territory.
--------------------------------------------------------------------------- */
CREATE TABLE project.SalesPerson (
    BusinessEntityID int NOT NULL,
    TerritoryID int NULL,
    CommissionPCT smallmoney NOT NULL,
    modified_date date NULL,

    CONSTRAINT PK_SalesPerson
        PRIMARY KEY (BusinessEntityID),

    CONSTRAINT FK_SalesPerson_Territory
        FOREIGN KEY (TerritoryID)
        REFERENCES project.Territory (TerritoryID)
);
GO


/* ---------------------------------------------------------------------------
   STORE

   Store customers may optionally be associated with a SalesPerson.
--------------------------------------------------------------------------- */
CREATE TABLE project.Store (
    BusinessEntityID int NOT NULL,
    Name nvarchar(50) NOT NULL,
    SalesPersonID int NULL,
    modified_date date NULL,

    CONSTRAINT PK_Store
        PRIMARY KEY (BusinessEntityID),

    CONSTRAINT FK_Store_SalesPerson
        FOREIGN KEY (SalesPersonID)
        REFERENCES project.SalesPerson (BusinessEntityID)
);
GO


/* ---------------------------------------------------------------------------
   CUSTOMER

   Customer master data used by SalesOrderHeader. A customer may represent an
   individual, a store, or both according to the original AdventureWorks model.
--------------------------------------------------------------------------- */
CREATE TABLE project.customer (
    CustomerID int NOT NULL,
    PersonID int NULL,
    StoreID int NULL,
    TerritoryID int NULL,
    modified_date date NULL,

    CONSTRAINT PK_customer
        PRIMARY KEY (CustomerID),

    CONSTRAINT FK_Customer_Store
        FOREIGN KEY (StoreID)
        REFERENCES project.Store (BusinessEntityID),

    CONSTRAINT FK_Customer_Territory
        FOREIGN KEY (TerritoryID)
        REFERENCES project.Territory (TerritoryID)
);
GO


/* ---------------------------------------------------------------------------
   PRODUCT COST HISTORY

   Project copy of Production.ProductCostHistory.

   Each row defines the StandardCost valid for a ProductID from StartDate until
   EndDate. The last interval will later be forced open-ended by the post-load
   transformation so that the latest cost remains valid on the shifted project
   timeline.

   The original AdventureWorks ModifiedDate is intentionally not retained. The
   project uses its own modified_date field instead.
--------------------------------------------------------------------------- */
CREATE TABLE project.productcosthistory (
    ProductID int NOT NULL,
    StartDate date NOT NULL,
    EndDate date NULL,
    StandardCost money NOT NULL,
    modified_date date NULL,

    CONSTRAINT PK_productcosthistory
        PRIMARY KEY (ProductID, StartDate),

    CONSTRAINT FK_ProductCostHistory_Product
        FOREIGN KEY (ProductID)
        REFERENCES project.Product (ProductID)
);
GO


/* ---------------------------------------------------------------------------
   PRODUCT LIST PRICE HISTORY

   Project copy of Production.ProductListPriceHistory.

   Each row defines the ListPrice valid for a ProductID over a specific time
   interval. This table is essential to the post-load process because order
   detail UnitPrice is reassigned from the price that is valid on the shifted
   OrderDate.

   The table therefore follows the same historical-table structure used for
   ProductCostHistory: ProductID + StartDate uniquely identify a price period.
--------------------------------------------------------------------------- */
CREATE TABLE project.ProductListPriceHistory (
    ProductID int NOT NULL,
    StartDate datetime NOT NULL,
    EndDate datetime NULL,
    ListPrice money NOT NULL,
    Modified_Date date NULL,

    CONSTRAINT PK_ProductListPriceHistory
        PRIMARY KEY (ProductID, StartDate),

    CONSTRAINT FK_ProductListPriceHistory_Product
        FOREIGN KEY (ProductID)
        REFERENCES project.Product (ProductID)
);
GO


/* ---------------------------------------------------------------------------
   SALES ORDER HEADER

   One row per sales order. The header must exist before the corresponding
   SalesOrderDetail rows can be inserted because detail references it through a
   foreign key.

   SubTotal is initially copied from AdventureWorks and retained as the
   historical commercial value associated with the original sales transaction.
--------------------------------------------------------------------------- */
CREATE TABLE project.Salesorderheader (
    SalesOrderID int NOT NULL,
    OrderDate date NOT NULL,
    DueDate date NOT NULL,
    ShipDate date NULL,
    OnlineOrderFlag bit NOT NULL,
    CustomerID int NULL,
    SalesPersonID int NULL,
    TerritoryID int NULL,
    SubTotal money NOT NULL,
    modified_date date NULL,

    CONSTRAINT PK_SalesOrderHeader
        PRIMARY KEY (SalesOrderID),

    CONSTRAINT FK_Header_Customer
        FOREIGN KEY (CustomerID)
        REFERENCES project.customer (CustomerID),

    CONSTRAINT FK_Header_SalesPerson
        FOREIGN KEY (SalesPersonID)
        REFERENCES project.SalesPerson (BusinessEntityID),

    CONSTRAINT FK_Header_Territory
        FOREIGN KEY (TerritoryID)
        REFERENCES project.Territory (TerritoryID)
);
GO

/* ---------------------------------------------------------------------------
   SPECIAL OFFER

   Stores the commercial discount rules used by sales transactions.

   Each offer defines the applicable quantity range and discount percentage.
   UnitPriceDiscount corresponds to DiscountPct in the original
   Sales.SpecialOffer table and is renamed to remain consistent with the
   terminology used in SalesOrderDetail.
--------------------------------------------------------------------------- */
CREATE TABLE project.SpecialOffer (
    SpecialOfferID int PRIMARY KEY NOT NULL,
    MinQty int NOT NULL,
    MaxQty int,
    Description nvarchar(255) NOT NULL,
    UnitPriceDiscount decimal(10,4) NOT NULL
);
GO


/* ---------------------------------------------------------------------------
   SALES ORDER DETAIL

   Transaction-level sales table. Each row belongs to a SalesOrderHeader and
   references a Product.

   UnitPrice and LineTotal are loaded from AdventureWorks as the historical
   commercial values associated with each original sales transaction.

   ProductListPriceHistory is maintained separately to preserve the time-valid
   product price structure used by the project and future simulated sales.

   No project modified_date column is required at detail level in the final
   model.
--------------------------------------------------------------------------- */
CREATE TABLE project.Salesorderdetail (
    SalesOrderDetailID int NOT NULL,
    SalesOrderID int NOT NULL,
    OrderQty smallint NOT NULL,
    ProductID int NOT NULL,
    UnitPrice money NOT NULL,
    LineTotal money NOT NULL,
    UnitPriceDiscount money NOT NULL,
    SpecialOfferID int NOT NULL,

    CONSTRAINT PK_SalesOrderDetail
        PRIMARY KEY (SalesOrderDetailID),

    CONSTRAINT FK_OrderDetail_Order
        FOREIGN KEY (SalesOrderID)
        REFERENCES project.Salesorderheader (SalesOrderID),

    CONSTRAINT FK_OrderDetail_Product
        FOREIGN KEY (ProductID)
        REFERENCES project.Product (ProductID)
);
GO




/* ---------------------------------------------------------------------------
   ACTION MONITORING TABLES

   Support structures used by the Action Monitoring workflow.

   ActionMonitoring_Import is a staging table for the CSV exported from the
   Commercial Actions analysis. Numeric values are intentionally imported as
   text because the source file may contain currency symbols, percentage signs
   and thousands separators.

   ActionMonitoringSnapshot stores the cleaned values at the moment the
   monitoring action is started, providing the baseline used to compare later
   sales performance in Power BI.
--------------------------------------------------------------------------- */

/* ============================================================
   STAGING TABLE
   Contiene i dati importati direttamente dal CSV.
   Le colonne numeriche sono NVARCHAR perché il CSV contiene
   simboli %, separatori delle migliaia, ecc.
   ============================================================ */

DROP TABLE IF EXISTS Project.ActionMonitoring_Import;
GO

CREATE TABLE Project.ActionMonitoring_Import
(
    Subcategory        nvarchar(100),
    Country            nvarchar(100),
    CurrentRevenues    nvarchar(100),
	CurrentGoalRevenues nvarchar(100),
    PercCurrentGoal    nvarchar(100),	
    DeltaCurrentGoal   nvarchar(100),
	PriorityType       nvarchar(50)
    
);
GO


/* ============================================================
   SNAPSHOT TABLE
   Contiene la situazione congelata al momento dell'import.
   ============================================================ */

DROP TABLE IF EXISTS Project.ActionMonitoringSnapshot;
GO

CREATE TABLE Project.ActionMonitoringSnapshot
(
    SnapshotDate                  date            NOT NULL,

    Subcategory                   nvarchar(100)   NOT NULL,
    Country                       nvarchar(100)   NOT NULL,
    PriorityType                  nvarchar(50),

    SnapshotRevenue               decimal(18,2),

    PercCurrentSnapshotGoal       decimal(18,4),

    DeltaCurrentSnapshotGoal      decimal(18,2),

    CurrentSnapshotGoal           decimal(18,2)
);
GO

/*
===============================================================================
 RESULT
===============================================================================
The complete project relational layer is now available and ready for the
initial data load and the Action Monitoring workflow.
===============================================================================
*/
