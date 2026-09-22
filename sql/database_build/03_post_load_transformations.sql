/*
===============================================================================
 AdventureWorks Sales Analytics
 03 - POST-LOAD TRANSFORMATIONS
 Clean / reproducible GitHub version
===============================================================================

Purpose:
- Move the original AdventureWorks historical timeline so that the latest
  historical order corresponds to the current project timeline.
- Apply the same temporal shift to product cost and list-price histories,
  keeping orders, selling prices and product costs temporally consistent.
- Keep the latest cost and price validity intervals open-ended so that they
  remain applicable to current and subsequently generated transactions.

Historical tables:
- project.ProductListPriceHistory stores the selling-price history for each
  product. After its validity intervals are aligned with the shifted order
  timeline, it can be used to identify the ListPrice valid on each OrderDate
  and to support consistent pricing of subsequent simulated transactions.

- project.ProductCostHistory stores the historical StandardCost for each
  product. Its validity intervals are shifted by the same amount so that the
  cost associated with a sale can be determined according to the OrderDate.
  This provides a temporally consistent cost basis for profit and margin
  analysis in the analytical layer.

The two tables therefore preserve the commercial conditions that were valid
at a specific point in time rather than relying only on the current ListPrice
and StandardCost stored in project.Product.

Run only after:
  01_create_project_schema.sql
  02_load_initial_data.sql

Logical transformation order:
  1. Shift SalesOrderHeader dates
  2. Shift ProductCostHistory validity intervals
  3. Shift ProductListPriceHistory validity intervals
  4. Keep the latest ProductCostHistory interval open-ended
  5. Keep the latest ProductListPriceHistory interval open-ended

Important:
- The same temporal shift must be applied to orders, costs and prices in order
  to preserve their original chronological relationships.
- Original AdventureWorks tables are treated as immutable reference sources.
- All transformed historical data is maintained inside the project schema.
===============================================================================
*/

USE AdventureWorks2022;
GO


/* ---------------------------------------------------------------------------
   1. ALIGN ORDER DATES TO THE CURRENT TIMELINE

   The latest OrderDate in the original AdventureWorks dataset is used as the
   anchor date. That date becomes today's date, while the original distance in
   days between all orders is preserved.

   DueDate and ShipDate are shifted by exactly the same amount so that the
   internal chronology of every order remains unchanged.
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
FROM project.Salesorderheader AS p
INNER JOIN Sales.SalesOrderHeader AS s
    ON p.SalesOrderID = s.SalesOrderID;
GO


/* ---------------------------------------------------------------------------
   2. ALIGN PRODUCT COST HISTORY TO THE ORDER TIMELINE

   ProductCostHistory must follow the same temporal transformation applied to
   SalesOrderHeader. This keeps each StandardCost validity interval consistent
   with the shifted order dates used later by the analytical model.

   The source Production.ProductCostHistory table is treated as the immutable
   reference containing the original StartDate and EndDate values.
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
FROM project.productcosthistory AS p
INNER JOIN Production.ProductCostHistory AS s
    ON p.ProductID = s.ProductID
   AND p.StartDate = CAST(s.StartDate AS date);
GO


/* ---------------------------------------------------------------------------
   3. ALIGN PRODUCT LIST-PRICE HISTORY TO THE ORDER TIMELINE

   The list-price history is shifted with exactly the same anchor used for the
   orders and cost history. As a result, the project retains a selling-price
   history that can be matched to the ListPrice valid on each transformed
   OrderDate and reused for subsequently generated transactions.

   Production.ProductListPriceHistory remains the immutable source reference;
   the aligned project table is the operational historical price structure.
--------------------------------------------------------------------------- */
DECLARE @max_orderdate_price date;

SELECT @max_orderdate_price = MAX(CAST(OrderDate AS date))
FROM Sales.SalesOrderHeader;

UPDATE p
SET
    p.StartDate = DATEADD(
        day,
        DATEDIFF(day, @max_orderdate_price, CAST(s.StartDate AS date)),
        CAST(GETDATE() AS date)
    ),
    p.EndDate =
        CASE
            WHEN s.EndDate IS NULL THEN NULL
            ELSE DATEADD(
                day,
                DATEDIFF(day, @max_orderdate_price, CAST(s.EndDate AS date)),
                CAST(GETDATE() AS date)
            )
        END,
    p.Modified_Date = CAST(GETDATE() AS date)
FROM project.ProductListPriceHistory AS p
INNER JOIN Production.ProductListPriceHistory AS s
    ON p.ProductID = s.ProductID
   AND p.StartDate = s.StartDate;
GO


/* ---------------------------------------------------------------------------
   4. KEEP THE LATEST PRODUCT COST RECORD OPEN-ENDED

   For each ProductID, the row with the most recent StartDate represents the
   currently valid StandardCost. Its EndDate is therefore forced to NULL.

   This is particularly important after the timeline shift because analytical
   joins need the latest cost interval to remain valid for current/future dates.
--------------------------------------------------------------------------- */
WITH LatestCost AS (
    SELECT
        ProductID,
        MAX(StartDate) AS MaxStartDate
    FROM project.productcosthistory
    GROUP BY ProductID
)
UPDATE c
SET
    c.EndDate = NULL,
    c.modified_date = CAST(GETDATE() AS date)
FROM project.productcosthistory AS c
INNER JOIN LatestCost AS l
    ON c.ProductID = l.ProductID
   AND c.StartDate = l.MaxStartDate
WHERE c.EndDate IS NOT NULL;
GO


/* ---------------------------------------------------------------------------
   5. KEEP THE LATEST PRODUCT LIST-PRICE RECORD OPEN-ENDED

   The same rule is applied to list prices: for each ProductID, the record with
   the latest StartDate is considered the currently valid price and is kept
   open-ended by setting EndDate = NULL.
--------------------------------------------------------------------------- */
WITH LatestPrice AS (
    SELECT
        ProductID,
        MAX(StartDate) AS MaxStartDate
    FROM project.ProductListPriceHistory
    GROUP BY ProductID
)
UPDATE p
SET
    p.EndDate = NULL,
    p.Modified_Date = CAST(GETDATE() AS date)
FROM project.ProductListPriceHistory AS p
INNER JOIN LatestPrice AS l
    ON p.ProductID = l.ProductID
   AND p.StartDate = l.MaxStartDate
WHERE p.EndDate IS NOT NULL;
GO





/*
===============================================================================
 DEVELOPMENT CLEAN-UP / FINAL LOGIC
===============================================================================
- No ALTER TABLE operations are required: final columns are defined in
  01_create_project_schema.sql.
- Original AdventureWorks history tables are used only as immutable source
  references for reconstructing the shifted timeline.
- project.ProductListPriceHistory provides the temporally aligned selling-price
  history used to determine the ListPrice valid for a given OrderDate and to
  support subsequent simulated sales.
- project.ProductCostHistory provides the corresponding historical StandardCost
  basis used for profit and margin analysis.
- Latest cost and price records are kept open-ended to support current and
  subsequently generated transactions.
===============================================================================
*/
