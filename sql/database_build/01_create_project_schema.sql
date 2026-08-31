/*
===============================================================================
 AdventureWorks Sales Analytics
 01 - CREATE PROJECT SCHEMA
 Clean / reproducible GitHub version
===============================================================================

Purpose:
- Create the final structure of the custom `project` schema.
- Columns added during development with ALTER TABLE are already incorporated.
- No data is loaded in this script.

Execution order:
  1) 01_create_project_schema.sql
  2) 02_load_initial_data.sql
  3) 03_post_load_transformations.sql
===============================================================================
*/

USE AdventureWorks2022;
GO

IF SCHEMA_ID('project') IS NULL
    EXEC('CREATE SCHEMA project');
GO


/* ---------------------------------------------------------------------------
   PRODUCT CATEGORY
--------------------------------------------------------------------------- */
CREATE TABLE project.ProductCategory_prj (
    ProductCategoryID int NOT NULL,
    Name nvarchar(50) NOT NULL,
    modified_date date NULL,

    CONSTRAINT PK_ProductCategory_prj
        PRIMARY KEY (ProductCategoryID)
);
GO


/* ---------------------------------------------------------------------------
   PRODUCT SUBCATEGORY
--------------------------------------------------------------------------- */
CREATE TABLE project.ProductSubCategory_prj (
    ProductSubcategoryID int NOT NULL,
    ProductCategoryID int NOT NULL,
    Name nvarchar(50) NOT NULL,
    modified_date date NULL,

    CONSTRAINT PK_ProductSubCategory_prj
        PRIMARY KEY (ProductSubcategoryID),

    CONSTRAINT FK_SubCategory_Category_prj
        FOREIGN KEY (ProductCategoryID)
        REFERENCES project.ProductCategory_prj (ProductCategoryID)
);
GO


/* ---------------------------------------------------------------------------
   PRODUCT
--------------------------------------------------------------------------- */
CREATE TABLE project.Product_prj (
    ProductID int NOT NULL,
    Name nvarchar(50) NOT NULL,
    DaysToManufacture int NOT NULL,
    ProductSubcategoryID int NULL,
    SafetyStockLevel int NOT NULL,
    ReorderPoint int NOT NULL,
    StandardCost money NOT NULL,
    ListPrice money NOT NULL,
    modified_date date NULL,

    CONSTRAINT PK_Product_prj
        PRIMARY KEY (ProductID),

    CONSTRAINT FK_Product_SubCategory_prj
        FOREIGN KEY (ProductSubcategoryID)
        REFERENCES project.ProductSubCategory_prj (ProductSubcategoryID)
);
GO


/* ---------------------------------------------------------------------------
   SALES TERRITORY
--------------------------------------------------------------------------- */
CREATE TABLE project.Territory_prj (
    TerritoryID int NOT NULL,
    Name nvarchar(50) NOT NULL,
    [Group] nvarchar(50) NOT NULL,
    modified_date date NULL,

    CONSTRAINT PK_Territory_prj
        PRIMARY KEY (TerritoryID)
);
GO


/* ---------------------------------------------------------------------------
   SALES PERSON
--------------------------------------------------------------------------- */
CREATE TABLE project.SalesPerson_prj (
    BusinessEntityID int NOT NULL,
    TerritoryID int NULL,
    CommissionPCT smallmoney NOT NULL,
    modified_date date NULL,

    CONSTRAINT PK_SalesPerson_prj
        PRIMARY KEY (BusinessEntityID),

    CONSTRAINT FK_SalesPerson_Territory_prj
        FOREIGN KEY (TerritoryID)
        REFERENCES project.Territory_prj (TerritoryID)
);
GO


/* ---------------------------------------------------------------------------
   STORE
--------------------------------------------------------------------------- */
CREATE TABLE project.Store_prj (
    BusinessEntityID int NOT NULL,
    Name nvarchar(50) NOT NULL,
    SalesPersonID int NULL,
    modified_date date NULL,

    CONSTRAINT PK_Store_prj
        PRIMARY KEY (BusinessEntityID),

    CONSTRAINT FK_Store_SalesPerson_prj
        FOREIGN KEY (SalesPersonID)
        REFERENCES project.SalesPerson_prj (BusinessEntityID)
);
GO


/* ---------------------------------------------------------------------------
   CUSTOMER
--------------------------------------------------------------------------- */
CREATE TABLE project.customer_prj (
    CustomerID int NOT NULL,
    PersonID int NULL,
    StoreID int NULL,
    TerritoryID int NULL,
    modified_date date NULL,

    CONSTRAINT PK_customer_prj
        PRIMARY KEY (CustomerID),

    CONSTRAINT FK_Customer_Store_prj
        FOREIGN KEY (StoreID)
        REFERENCES project.Store_prj (BusinessEntityID),

    CONSTRAINT FK_Customer_Territory_prj
        FOREIGN KEY (TerritoryID)
        REFERENCES project.Territory_prj (TerritoryID)
);
GO


/* ---------------------------------------------------------------------------
   PRODUCT COST HISTORY

   Clean project copy of Production.ProductCostHistory.
   The original source ModifiedDate column is intentionally not retained:
   the project uses its own modified_date field.
--------------------------------------------------------------------------- */
CREATE TABLE project.productcosthistory_prj (
    ProductID int NOT NULL,
    StartDate date NOT NULL,
    EndDate date NULL,
    StandardCost money NOT NULL,
    modified_date date NULL,

    CONSTRAINT PK_productcosthistory_prj
        PRIMARY KEY (ProductID, StartDate),

    CONSTRAINT FK_ProductCostHistory_Product_prj
        FOREIGN KEY (ProductID)
        REFERENCES project.Product_prj (ProductID)
);
GO


/* ---------------------------------------------------------------------------
   SALES ORDER HEADER
--------------------------------------------------------------------------- */
CREATE TABLE project.Salesorderheader_prj (
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

    CONSTRAINT PK_SalesOrderHeader_prj
        PRIMARY KEY (SalesOrderID),

    CONSTRAINT FK_Header_Customer_prj
        FOREIGN KEY (CustomerID)
        REFERENCES project.customer_prj (CustomerID),

    CONSTRAINT FK_Header_SalesPerson_prj
        FOREIGN KEY (SalesPersonID)
        REFERENCES project.SalesPerson_prj (BusinessEntityID),

    CONSTRAINT FK_Header_Territory_prj
        FOREIGN KEY (TerritoryID)
        REFERENCES project.Territory_prj (TerritoryID)
);
GO


/* ---------------------------------------------------------------------------
   SALES ORDER DETAIL

   modified_date is intentionally not included because it was removed from the
   final development version.
--------------------------------------------------------------------------- */
CREATE TABLE project.Salesorderdetail_prj (
    SalesOrderDetailID int NOT NULL,
    SalesOrderID int NOT NULL,
    OrderQty smallint NOT NULL,
    ProductID int NOT NULL,
    UnitPrice money NOT NULL,
    LineTotal money NOT NULL,
    UnitPriceDiscount money NOT NULL,
    SpecialOfferID int NOT NULL,

    CONSTRAINT PK_SalesOrderDetail_prj
        PRIMARY KEY (SalesOrderDetailID),

    CONSTRAINT FK_OrderDetail_Order_prj
        FOREIGN KEY (SalesOrderID)
        REFERENCES project.Salesorderheader_prj (SalesOrderID),

    CONSTRAINT FK_OrderDetail_Product_prj
        FOREIGN KEY (ProductID)
        REFERENCES project.Product_prj (ProductID)
);
GO
