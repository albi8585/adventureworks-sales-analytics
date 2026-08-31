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
CREATE TABLE project.ProductCategory(
    ProductCategoryID int NOT NULL,
    Name nvarchar(50) NOT NULL,
    modified_date date NULL,

    CONSTRAINT PK_ProductCategory
        PRIMARY KEY (ProductCategoryID)
);
GO


/* ---------------------------------------------------------------------------
   PRODUCT SUBCATEGORY
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

   Clean project copy of Production.ProductCostHistory.
   The original source ModifiedDate column is intentionally not retained:
   the project uses its own modified_date field.
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
   SALES ORDER HEADER
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
   SALES ORDER DETAIL

   modified_date is intentionally not included because it was removed from the
   final development version.
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
