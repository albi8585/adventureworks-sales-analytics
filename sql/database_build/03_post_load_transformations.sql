/*
===============================================================================
 AdventureWorks Sales Analytics
 03 - POST-LOAD TRANSFORMATIONS
 Clean / reproducible GitHub version
===============================================================================

Purpose:
- Align the historical AdventureWorks timeline with the current date.
- Keep ProductCostHistory temporally consistent with the shifted orders.
- Recalculate commercial values after the timeline transformation.

Run only after:
  01_create_project_schema.sql
  02_load_initial_data.sql

Transformation order matters:
  1. Shift SalesOrderHeader dates
  2. Shift ProductCostHistory dates
  3. Keep latest product cost open-ended
  4. Update order-detail prices
  5. Recalculate LineTotal
  6. Recalculate SalesOrderHeader SubTotal
===============================================================================
*/

USE AdventureWorks2022;
GO


/* ---------------------------------------------------------------------------
   1. ALIGN ORDER DATES TO THE CURRENT DATE

   The maximum original AdventureWorks OrderDate becomes today.
   The distance in days among all historical dates is preserved.
--------------------------------------------------------------------------- */
DECLARE @max_orderdate date;

SELECT @max_orderdate = MAX(CAST(OrderDate AS date))
FROM Sales.SalesOrderHeader;

UPDATE p
SET
    p.OrderDate = CAST(
        DATEADD(day, DATEDIFF(day, @max_orderdate, s.OrderDate), GETDATE())
        AS date
    ),
    p.DueDate = CAST(
        DATEADD(day, DATEDIFF(day, @max_orderdate, s.DueDate), GETDATE())
        AS date
    ),
    p.ShipDate =
        CASE
            WHEN s.ShipDate IS NULL THEN NULL
            ELSE CAST(
                DATEADD(day, DATEDIFF(day, @max_orderdate, s.ShipDate), GETDATE())
                AS date
            )
        END,
    p.modified_date = CAST(GETDATE() AS date)
FROM project.Salesorderheader_prj AS p
INNER JOIN Sales.SalesOrderHeader AS s
    ON p.SalesOrderID = s.SalesOrderID;
GO


/* ---------------------------------------------------------------------------
   2. ALIGN PRODUCT COST HISTORY TO THE SAME TIMELINE

   The original AdventureWorks ProductCostHistory table is used directly as
   the immutable reference source, replacing the old helper table `pippo2`.
--------------------------------------------------------------------------- */
DECLARE @max_orderdate_cost date;

SELECT @max_orderdate_cost = MAX(CAST(OrderDate AS date))
FROM Sales.SalesOrderHeader;

UPDATE p
SET
    p.StartDate = CAST(
        DATEADD(
            day,
            DATEDIFF(day, @max_orderdate_cost, CAST(s.StartDate AS date)),
            GETDATE()
        )
        AS date
    ),
    p.EndDate =
        CASE
            WHEN s.EndDate IS NULL THEN NULL
            ELSE CAST(
                DATEADD(
                    day,
                    DATEDIFF(day, @max_orderdate_cost, CAST(s.EndDate AS date)),
                    GETDATE()
                )
                AS date
            )
        END,
    p.modified_date = CAST(GETDATE() AS date)
FROM project.productcosthistory_prj AS p
INNER JOIN Production.ProductCostHistory AS s
    ON p.ProductID = s.ProductID
   AND p.StartDate = CAST(s.StartDate AS date);
GO


/* ---------------------------------------------------------------------------
   3. KEEP THE LATEST COST RECORD OPEN-ENDED

   For every product, the row with the latest StartDate has EndDate = NULL.
--------------------------------------------------------------------------- */
;WITH LatestCost AS (
    SELECT
        ProductID,
        MAX(StartDate) AS MaxStartDate
    FROM project.productcosthistory_prj
    GROUP BY ProductID
)
UPDATE c
SET
    c.EndDate = NULL,
    c.modified_date = CAST(GETDATE() AS date)
FROM project.productcosthistory_prj AS c
INNER JOIN LatestCost AS l
    ON c.ProductID = l.ProductID
   AND c.StartDate = l.MaxStartDate
WHERE c.EndDate IS NOT NULL;
GO


/* ---------------------------------------------------------------------------
   4. UPDATE ORDER-DETAIL PRICES

   Price is selected according to the order date and the validity interval in
   Production.ProductListPriceHistory.

   Note:
   This retains the business logic used in the development version.
--------------------------------------------------------------------------- */
UPDATE d
SET d.UnitPrice = h.ListPrice
FROM project.Salesorderdetail_prj AS d
INNER JOIN project.Salesorderheader_prj AS o
    ON d.SalesOrderID = o.SalesOrderID
INNER JOIN Production.ProductListPriceHistory AS h
    ON d.ProductID = h.ProductID
   AND o.OrderDate >= CAST(h.StartDate AS date)
   AND (
        o.OrderDate < CAST(h.EndDate AS date)
        OR h.EndDate IS NULL
   );
GO


/* ---------------------------------------------------------------------------
   5. RECALCULATE LINE TOTAL INCLUDING DISCOUNT
--------------------------------------------------------------------------- */
UPDATE project.Salesorderdetail_prj
SET LineTotal = CAST(
    (UnitPrice * OrderQty) * (1 - UnitPriceDiscount)
    AS money
);
GO


/* ---------------------------------------------------------------------------
   6. RECALCULATE ORDER SUBTOTAL FROM THE UPDATED DETAILS
--------------------------------------------------------------------------- */
;WITH OrderTotals AS (
    SELECT
        SalesOrderID,
        CAST(SUM(LineTotal) AS money) AS TotalOrder
    FROM project.Salesorderdetail_prj
    GROUP BY SalesOrderID
)
UPDATE h
SET
    h.SubTotal = t.TotalOrder,
    h.modified_date = CAST(GETDATE() AS date)
FROM project.Salesorderheader_prj AS h
INNER JOIN OrderTotals AS t
    ON h.SalesOrderID = t.SalesOrderID;
GO


/*
===============================================================================
 DEVELOPMENT CLEAN-UP APPLIED
===============================================================================
Removed / absorbed:
- ALTER TABLE statements for final columns.
- Product update for SafetyStockLevel / ReorderPoint / StandardCost / ListPrice.
- Customer ALTER + UPDATE for PersonID.
- Permanent helper tables `pippo` and `pippo2`; both are replaced by direct
  updates against the original AdventureWorks source tables.
- DROP TABLE development statements.
- ProductCostHistory source ModifiedDate / later DROP COLUMN ambiguity.
- SalesOrderDetail modified_date, because it was removed in the final version.
- Fixed INSERT order: SalesOrderHeader is loaded before SalesOrderDetail.
===============================================================================
*/
