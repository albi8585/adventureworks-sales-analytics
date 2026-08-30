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
  4. project.calendario_prj                -> Date dimension

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

DROP TABLE IF EXISTS project.dimensioni_type_customer_prj;
GO

CREATE TABLE project.dimensioni_type_customer_prj (
    customerId int NOT NULL,
    customer_name nvarchar(200) NOT NULL,
    customer_type nvarchar(30) NOT NULL,

    CONSTRAINT PK_dimensioni_type_customer_prj
        PRIMARY KEY (customerId)
);
GO

INSERT INTO project.dimensioni_type_customer_prj (
    customerId,
    customer_name,
    customer_type
)
SELECT
    c.CustomerID,
    COALESCE(
        s.Name,
        NULLIF(
            LTRIM(RTRIM(
                CONCAT(
                    COALESCE(p.FirstName, ''),
                    CASE
                        WHEN p.MiddleName IS NOT NULL
                             AND LTRIM(RTRIM(p.MiddleName)) <> ''
                        THEN ' ' + p.MiddleName
                        ELSE ''
                    END,
                    CASE
                        WHEN p.LastName IS NOT NULL
                             AND LTRIM(RTRIM(p.LastName)) <> ''
                        THEN ' ' + p.LastName
                        ELSE ''
                    END
                )
            )),
            ''
        ),
        CONCAT('Customer ', c.CustomerID)
    ) AS customer_name,
    CASE
        WHEN c.StoreID IS NOT NULL THEN 'Store'
        WHEN c.PersonID IS NOT NULL THEN 'Individual'
        ELSE 'Other'
    END AS customer_type
FROM project.customer_prj AS c
LEFT JOIN project.Store_prj AS s
    ON c.StoreID = s.BusinessEntityID
LEFT JOIN Person.Person AS p
    ON c.PersonID = p.BusinessEntityID;
GO


/* ---------------------------------------------------------------------------
   2. PRODUCT HIERARCHY DIMENSION

   Denormalizes the product hierarchy:
   Product -> Subcategory -> Category

   This simplifies filtering and drill-down operations in Power BI.
--------------------------------------------------------------------------- */

DROP TABLE IF EXISTS project.dimensioni_prod_cat_prj;
GO

CREATE TABLE project.dimensioni_prod_cat_prj (
    productid int NOT NULL,
    product nvarchar(50) NOT NULL,
    subcategory nvarchar(50) NULL,
    category nvarchar(50) NULL,

    CONSTRAINT PK_dimensioni_prod_cat_prj
        PRIMARY KEY (productid)
);
GO

INSERT INTO project.dimensioni_prod_cat_prj (
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
FROM project.Product_prj AS p
LEFT JOIN project.ProductSubCategory_prj AS sc
    ON p.ProductSubcategoryID = sc.ProductSubcategoryID
LEFT JOIN project.ProductCategory_prj AS c
    ON sc.ProductCategoryID = c.ProductCategoryID;
GO


/* ---------------------------------------------------------------------------
   3. DATE DIMENSION

   The calendar starts from the minimum order date available in the project
   and extends one year beyond the later of:
   - today's date
   - the maximum order date currently loaded

   The extra year allows the daily simulated-sales pipeline to continue adding
   data without immediately requiring the calendar table to be rebuilt.
--------------------------------------------------------------------------- */

DROP TABLE IF EXISTS project.calendario_prj;
GO

CREATE TABLE project.calendario_prj (
    [data] date NOT NULL,
    anno int NOT NULL,
    mese int NOT NULL,
    trimestre int NOT NULL,
    data_inizio_trimestre date NOT NULL,
    data_inizio_mese date NOT NULL,

    CONSTRAINT PK_calendario_prj
        PRIMARY KEY ([data])
);
GO

DECLARE @calendar_start date;
DECLARE @calendar_end date;
DECLARE @max_order_date date;

SELECT
    @calendar_start = MIN(OrderDate),
    @max_order_date = MAX(OrderDate)
FROM project.Salesorderheader_prj;

SET @calendar_start = COALESCE(@calendar_start, DATEFROMPARTS(YEAR(GETDATE()), 1, 1));

SET @calendar_end =
    DATEADD(
        year,
        1,
        CASE
            WHEN @max_order_date IS NOT NULL
                 AND @max_order_date > CAST(GETDATE() AS date)
            THEN @max_order_date
            ELSE CAST(GETDATE() AS date)
        END
    );

;WITH CalendarDates AS (
    SELECT @calendar_start AS [data]

    UNION ALL

    SELECT DATEADD(day, 1, [data])
    FROM CalendarDates
    WHERE [data] < @calendar_end
)
INSERT INTO project.calendario_prj (
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
    DATEFROMPARTS(
        YEAR([data]),
        ((DATEPART(quarter, [data]) - 1) * 3) + 1,
        1
    ) AS data_inizio_trimestre,
    DATEFROMPARTS(
        YEAR([data]),
        MONTH([data]),
        1
    ) AS data_inizio_mese
FROM CalendarDates
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
          +-- OrderDate   -> project.calendario_prj.data

   Product and customer dimensions are deliberately denormalized for reporting.
   The normalized project tables remain available for ETL and SQL processing.
--------------------------------------------------------------------------- */
