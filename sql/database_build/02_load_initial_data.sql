/*
===============================================================================
 AdventureWorks Sales Analytics
 02 - LOAD INITIAL DATA
 Clean / reproducible GitHub version
===============================================================================

Purpose:
- Populate the `project` schema from the original AdventureWorks2022 tables.
- Values that were previously populated through redundant UPDATE statements
  are inserted directly here.
- modified_date records the date on which this initial project load is run.

Run only after:
  01_create_project_schema.sql
===============================================================================
*/

USE AdventureWorks2022;
GO

DECLARE @load_date date = CAST(GETDATE() AS date);


/* ---------------------------------------------------------------------------
   PRODUCT CATEGORY
--------------------------------------------------------------------------- */
INSERT INTO project.ProductCategory_prj (
    ProductCategoryID,
    Name,
    modified_date
)
SELECT
    ProductCategoryID,
    Name,
    @load_date
FROM Production.ProductCategory;


/* ---------------------------------------------------------------------------
   PRODUCT SUBCATEGORY
--------------------------------------------------------------------------- */
INSERT INTO project.ProductSubCategory_prj (
    ProductSubcategoryID,
    ProductCategoryID,
    Name,
    modified_date
)
SELECT
    ProductSubcategoryID,
    ProductCategoryID,
    Name,
    @load_date
FROM Production.ProductSubcategory;


/* ---------------------------------------------------------------------------
   PRODUCT
   SafetyStockLevel, ReorderPoint, StandardCost and ListPrice are loaded
   directly here instead of being added/updated later.
--------------------------------------------------------------------------- */
INSERT INTO project.Product_prj (
    ProductID,
    Name,
    DaysToManufacture,
    ProductSubcategoryID,
    SafetyStockLevel,
    ReorderPoint,
    StandardCost,
    ListPrice,
    modified_date
)
SELECT
    ProductID,
    Name,
    DaysToManufacture,
    ProductSubcategoryID,
    SafetyStockLevel,
    ReorderPoint,
    StandardCost,
    ListPrice,
    @load_date
FROM Production.Product;


/* ---------------------------------------------------------------------------
   SALES TERRITORY
--------------------------------------------------------------------------- */
INSERT INTO project.Territory_prj (
    TerritoryID,
    Name,
    [Group],
    modified_date
)
SELECT
    TerritoryID,
    Name,
    [Group],
    @load_date
FROM Sales.SalesTerritory;


/* ---------------------------------------------------------------------------
   SALES PERSON
--------------------------------------------------------------------------- */
INSERT INTO project.SalesPerson_prj (
    BusinessEntityID,
    TerritoryID,
    CommissionPCT,
    modified_date
)
SELECT
    BusinessEntityID,
    TerritoryID,
    CommissionPCT,
    @load_date
FROM Sales.SalesPerson;


/* ---------------------------------------------------------------------------
   STORE
--------------------------------------------------------------------------- */
INSERT INTO project.Store_prj (
    BusinessEntityID,
    Name,
    SalesPersonID,
    modified_date
)
SELECT
    BusinessEntityID,
    Name,
    SalesPersonID,
    @load_date
FROM Sales.Store;


/* ---------------------------------------------------------------------------
   CUSTOMER
   PersonID is loaded directly here instead of ALTER TABLE + UPDATE.
--------------------------------------------------------------------------- */
INSERT INTO project.customer_prj (
    CustomerID,
    PersonID,
    StoreID,
    TerritoryID,
    modified_date
)
SELECT
    CustomerID,
    PersonID,
    StoreID,
    TerritoryID,
    @load_date
FROM Sales.Customer;


/* ---------------------------------------------------------------------------
   PRODUCT COST HISTORY
   The source StartDate/EndDate are converted directly to DATE.
--------------------------------------------------------------------------- */
INSERT INTO project.productcosthistory_prj (
    ProductID,
    StartDate,
    EndDate,
    StandardCost,
    modified_date
)
SELECT
    ProductID,
    CAST(StartDate AS date),
    CAST(EndDate AS date),
    StandardCost,
    @load_date
FROM Production.ProductCostHistory;


/* ---------------------------------------------------------------------------
   SALES ORDER HEADER

   Header MUST be loaded before detail because Salesorderdetail_prj has a
   foreign key to Salesorderheader_prj.
--------------------------------------------------------------------------- */
INSERT INTO project.Salesorderheader_prj (
    SalesOrderID,
    OrderDate,
    DueDate,
    ShipDate,
    OnlineOrderFlag,
    CustomerID,
    SalesPersonID,
    TerritoryID,
    SubTotal,
    modified_date
)
SELECT
    SalesOrderID,
    CAST(OrderDate AS date),
    CAST(DueDate AS date),
    CAST(ShipDate AS date),
    OnlineOrderFlag,
    CustomerID,
    SalesPersonID,
    TerritoryID,
    SubTotal,
    @load_date
FROM Sales.SalesOrderHeader;


/* ---------------------------------------------------------------------------
   SALES ORDER DETAIL
--------------------------------------------------------------------------- */
INSERT INTO project.Salesorderdetail_prj (
    SalesOrderDetailID,
    SalesOrderID,
    OrderQty,
    ProductID,
    UnitPrice,
    LineTotal,
    UnitPriceDiscount,
    SpecialOfferID
)
SELECT
    SalesOrderDetailID,
    SalesOrderID,
    OrderQty,
    ProductID,
    UnitPrice,
    CAST(LineTotal AS money),
    UnitPriceDiscount,
    SpecialOfferID
FROM Sales.SalesOrderDetail;
GO
