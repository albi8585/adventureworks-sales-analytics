/*
===============================================================================
 AdventureWorks Sales Analytics
 04 - CREATE POWER BI DIMENSIONS
===============================================================================

Purpose:
- Build the denormalized dimension tables used by the Power BI star schema.
- project.Territory_prj already exists in the base project schema and is used
  directly as the geographic / sales-territory dimension.

Power BI dimensions:
  1. project.Territory_prj                 -> Territory / geographic dimension
  2. project.dimensioni_type_customer_prj  -> Customer dimension
  3. project.dimensioni_prod_cat_prj       -> Product hierarchy dimension
  4. project.calendar                -> Date dimension

Run after:
  01_create_project_schema.sql
  02_load_initial_data.sql
  03_post_load_transformations.sql
===============================================================================
*/

USE AdventureWorks2022;
GO


/* ---------------------------------------------------------------------------
   1. CUSTOMER DIMENSION

   Creates a single reporting-ready customer table combining:
   - customer identifier
   - individual or store name
   - customer type
--------------------------------------------------------------------------- */

DROP TABLE IF EXISTS project.dimension_type_customer;
GO

CREATE TABLE project.dimension_type_customer (
    customerId int NOT NULL,
    customer_name nvarchar(200) NOT NULL,
    customer_type nvarchar(30) NOT NULL,

    CONSTRAINT PK_dimension_type_customer
        PRIMARY KEY (customerId)
);
GO

INSERT INTO project.dimension_type_customer (
    customerId,
    customer_name,
    customer_type
)

-- Store customers
SELECT
    c.CustomerID,
    s.Name AS customer_name,
    'Store' AS customer_type
FROM project.customer_prj AS c
INNER JOIN project.Store_prj AS s
    ON c.StoreID = s.BusinessEntityID
WHERE s.Name IS NOT NULL

UNION ALL

-- Individual customers
SELECT
    c.CustomerID,
    CONCAT(p.FirstName, ' ', p.LastName) AS customer_name,
    'Individual' AS customer_type
FROM project.customer_prj AS c
INNER JOIN Person.Person AS p
    ON c.PersonID = p.BusinessEntityID
WHERE p.FirstName IS NOT NULL
  AND p.LastName IS NOT NULL;
GO




/* ---------------------------------------------------------------------------
   2. PRODUCT HIERARCHY DIMENSION

   Denormalizes the product hierarchy:
   Product -> Subcategory -> Category

   This simplifies filtering and drill-down operations in Power BI.
--------------------------------------------------------------------------- */

DROP TABLE IF EXISTS project.dimension_prod_cat;
GO

CREATE TABLE project.dimension_prod_cat (
    productid int NOT NULL,
    product nvarchar(50) NOT NULL,
    subcategory nvarchar(50) NULL,
    category nvarchar(50) NULL,

    CONSTRAINT PK_dimension_prod_cat
        PRIMARY KEY (productid)
);
GO

INSERT INTO project.dimension_prod_cat (
    productid,
    product,
    subcategory,
    category
)
SELECT
    p.ProductID,
    p.Name AS product,
    sc.Name AS subcategory,
    c.Name AS category
FROM project.Product AS p
LEFT JOIN project.ProductSubCategory AS sc
    ON p.ProductSubcategoryID = sc.ProductSubcategoryID
LEFT JOIN project.ProductCategory AS c
    ON sc.ProductCategoryID = c.ProductCategoryID;
GO


/* ---------------------------------------------------------------------------
   3. DATE DIMENSION

   Fixed calendar dimension used by Power BI.
   The logic follows the original project calendar script and creates one row
   per day from 2011-01-01 through 2030-12-31.
--------------------------------------------------------------------------- */

DROP TABLE IF EXISTS project.calendar;
GO

CREATE TABLE project.calendar (
    [data] date NOT NULL,
    anno int NULL,
    mese int NULL,
    trimestre int NULL,
    data_inizio_trimestre date NULL,
    data_inizio_mese date NULL,

    CONSTRAINT PK_calendar
        PRIMARY KEY ([data])
);
GO

;WITH cte_calendario AS (
    SELECT CAST('2011-01-01' AS date) AS [data]

    UNION ALL

    SELECT DATEADD(day, 1, [data])
    FROM cte_calendario
    WHERE [data] < CAST('2030-12-31' AS date)
)
INSERT INTO project.calendar (
    [data],
    anno,
    mese,
    trimestre,
    data_inizio_trimestre,
    data_inizio_mese
)
SELECT
    [data],
    YEAR([data]) AS anno,
    MONTH([data]) AS mese,
    DATEPART(quarter, [data]) AS trimestre,
    DATEADD(quarter, DATEDIFF(quarter, 0, [data]), 0) AS data_inizio_trimestre,
    DATEFROMPARTS(YEAR([data]), MONTH([data]), 1) AS data_inizio_mese
FROM cte_calendario
OPTION (MAXRECURSION 0);
GO


/* ---------------------------------------------------------------------------
   POWER BI STAR-SCHEMA NOTES

   The main sales fact layer can be related to the dimensions through:

     Sales / fact dataset
          |
          +-- ProductID   -> project.dimensioni_prod_cat_prj.productid
          |
          +-- CustomerID  -> project.dimensioni_type_customer_prj.customerId
          |
          +-- TerritoryID -> project.Territory_prj.TerritoryID
          |
          +-- OrderDate   -> project.calendar.data

   Product and customer dimensions are deliberately denormalized for reporting.
   The normalized project tables remain available for ETL and SQL processing.
--------------------------------------------------------------------------- */
