/*
===============================================================================
 AdventureWorks Sales Analytics
 02 - LOAD INITIAL DATA
 Clean / reproducible GitHub version
===============================================================================

Purpose:
- Populate the tables created in the custom `project` schema with the original
  AdventureWorks2022 data.
- Preserve the original source tables unchanged.
- Load all attributes directly into their final project columns, avoiding
  development-time ALTER TABLE / UPDATE operations.
- Record the execution date in the project audit columns (`modified_date` or
  `Modified_Date`).

Run only after:
  01_create_project_schema.sql

Next step:
  03_post_load_transformations.sql

Important:
- This script performs the initial copy only.
- Historical order, cost and price dates are still the original AdventureWorks
  dates at this stage.
- The temporal shift of orders, product costs and list prices is intentionally
  performed later in 03_post_load_transformations.sql.
===============================================================================
*/

USE AdventureWorks2022;
GO

DECLARE @load_date date = CAST(GETDATE() AS date);


/* ---------------------------------------------------------------------------
   1. PRODUCT CATEGORY

   Load the top level of the product hierarchy first because ProductSubCategory
   depends on it through a foreign key.
--------------------------------------------------------------------------- */
INSERT INTO project.ProductCategory (
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
   2. PRODUCT SUBCATEGORY

   Loaded after ProductCategory so that the category foreign key is already
   available.
--------------------------------------------------------------------------- */
INSERT INTO project.ProductSubCategory (
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
   3. PRODUCT

   Load the product master after its hierarchy tables.

   SafetyStockLevel, ReorderPoint, StandardCost and ListPrice are copied
   directly into the final project structure. Historical cost and list-price
   changes are loaded separately in the two history tables below.
--------------------------------------------------------------------------- */
INSERT INTO project.Product (
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
   4. SALES TERRITORY

   Territory must be loaded before SalesPerson and Customer because both tables
   may reference it.
--------------------------------------------------------------------------- */
INSERT INTO project.Territory (
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
   5. SALES PERSON

   Loaded after Territory to satisfy FK_SalesPerson_Territory.
--------------------------------------------------------------------------- */
INSERT INTO project.SalesPerson (
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
   6. STORE

   Store is loaded after SalesPerson because SalesPersonID is a foreign key in
   the project model.
--------------------------------------------------------------------------- */
INSERT INTO project.Store (
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
   7. CUSTOMER

   Customer is loaded after Store and Territory so that all project foreign-key
   references are already available.
--------------------------------------------------------------------------- */
INSERT INTO project.customer (
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
   8. PRODUCT COST HISTORY

   Copy the historical StandardCost validity intervals.

   StartDate and EndDate are converted to DATE because the project cost-history
   table does not require a time component. The dates are still on the original
   AdventureWorks timeline here; they are shifted in the post-load script.
--------------------------------------------------------------------------- */
INSERT INTO project.productcosthistory (
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
   9. PRODUCT LIST PRICE HISTORY

   Copy the historical ListPrice validity intervals from AdventureWorks.

   This project table will later be shifted to the same timeline as the orders.
   It preserves the ListPrice validity periods required to identify the selling
   price applicable on a given OrderDate and to support subsequent simulated
   sales on the project timeline.

   The source ModifiedDate is deliberately excluded; Modified_Date records the
   project load/transformation date instead.
--------------------------------------------------------------------------- */
INSERT INTO project.ProductListPriceHistory (
    ProductID,
    StartDate,
    EndDate,
    ListPrice,
    Modified_Date
)
SELECT
    ProductID,
    StartDate,
    EndDate,
    ListPrice,
    @load_date
FROM Production.ProductListPriceHistory;


/* ---------------------------------------------------------------------------
   10. SALES ORDER HEADER

   Header must be loaded before SalesOrderDetail because detail rows reference
   SalesOrderID through FK_OrderDetail_Order.

   Dates and SubTotal are initially copied from AdventureWorks. Order dates are
   later shifted to the project timeline in 03_post_load_transformations.sql,
   while the original historical SubTotal is retained.
--------------------------------------------------------------------------- */
INSERT INTO project.Salesorderheader (
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
   11. SALES ORDER DETAIL

   Transaction rows are loaded last because they depend on both Product and
   SalesOrderHeader.

   UnitPrice, LineTotal and UnitPriceDiscount are copied from AdventureWorks as
   the original historical commercial values of each transaction.

   project.ProductListPriceHistory is loaded separately so that the project also
   retains the time-valid list prices used for future/simulated transactions.
--------------------------------------------------------------------------- */
INSERT INTO project.Salesorderdetail (
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

/* ---------------------------------------------------------------------------
   12. SPECIAL OFFER

   Load the subset of AdventureWorks special offers used by the project,
   including quantity thresholds, descriptions and discount percentages.

   DiscountPct from Sales.SpecialOffer is renamed to UnitPriceDiscount in the
   project layer to remain consistent with SalesOrderDetail terminology.
--------------------------------------------------------------------------- */
INSERT INTO project.SpecialOffer (
    SpecialOfferID,
    MinQty,
    MaxQty,
    Description,
    UnitPriceDiscount
)
SELECT
    SpecialOfferID,
    MinQty,
    MaxQty,
    Description,
    DiscountPct
FROM Sales.SpecialOffer
WHERE SpecialOfferID < 7;
GO


/*
===============================================================================
 RESULT
===============================================================================
The project schema now contains the initial AdventureWorks data in its original
historical timeline.

No additional *_prj copy of ProductListPriceHistory is created: the canonical
project table is `project.ProductListPriceHistory`.

The database is now ready for:
  03_post_load_transformations.sql
===============================================================================
*/
