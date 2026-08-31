/*
===============================================================================
 AdventureWorks Sales Analytics
 CUSTOMER ANALYTICS VIEWS
===============================================================================

Purpose:
- Create SQL views used by the Power BI customer-behaviour analysis.
- Measure repeat-purchase rates over different time horizons.
- Analyse sequential purchases between product subcategories.
- Measure purchase frequency and time between orders by territory.

Analytics flow:

  SalesOrderHeader + SalesOrderDetail + Dimensions
                         |
             +-----------+-----------+
             |           |           |
             v           v           v
      Repeat Purchase  Purchase    Purchase
          Rate         Sequence    Frequency
             |           |           |
             +-----------+-----------+
                         |
                         v
                   Power BI layer

===============================================================================
*/

USE AdventureWorks2022;
GO


/* ===========================================================================
   1. CUSTOMER REPEAT PURCHASE RATE
   View: project.VIEW_customer_repeat_purchase_rate

   Purpose:
   Measure the share of eligible customers who place at least one additional
   order within 3, 6 and 12 months after their first purchase.

   Logic:

      Customer orders
            |
            v
      First order date
            |
            v
      Repeat purchase within:
        3m / 6m / 12m
            |
            v
      Average repeat rate

   Customers are included in each KPI only when enough time has elapsed since
   their first order. This avoids penalising recent customers who have not yet
   had the full 3, 6 or 12-month observation window.
=========================================================================== */

CREATE OR ALTER VIEW project.VIEW_customer_repeat_purchase_rate AS

WITH first_purchase AS (
    SELECT
        CustomerID,
        MIN(CAST(OrderDate AS date)) AS FirstOrderDate
    FROM project.Salesorderheader
    GROUP BY CustomerID
),

customer_repeat AS (
    SELECT
        p.CustomerID,
        p.FirstOrderDate,

        MAX(
            CASE
                WHEN o.OrderDate > p.FirstOrderDate
                 AND o.OrderDate <= DATEADD(MONTH, 3, p.FirstOrderDate)
                THEN 1 ELSE 0
            END
        ) AS repeat_3m,

        MAX(
            CASE
                WHEN o.OrderDate > p.FirstOrderDate
                 AND o.OrderDate <= DATEADD(MONTH, 6, p.FirstOrderDate)
                THEN 1 ELSE 0
            END
        ) AS repeat_6m,

        MAX(
            CASE
                WHEN o.OrderDate > p.FirstOrderDate
                 AND o.OrderDate <= DATEADD(MONTH, 12, p.FirstOrderDate)
                THEN 1 ELSE 0
            END
        ) AS repeat_12m

    FROM first_purchase AS p
    LEFT JOIN project.Salesorderheader AS o
        ON p.CustomerID = o.CustomerID

    GROUP BY
        p.CustomerID,
        p.FirstOrderDate
)

SELECT
    CAST(
        AVG(
            CASE
                WHEN FirstOrderDate <= DATEADD(MONTH, -3, CAST(GETDATE() AS date))
                THEN CAST(repeat_3m AS decimal(10,4))
            END
        )
        AS decimal(10,4)
    ) AS avg_repeat_rate_3m,

    CAST(
        AVG(
            CASE
                WHEN FirstOrderDate <= DATEADD(MONTH, -6, CAST(GETDATE() AS date))
                THEN CAST(repeat_6m AS decimal(10,4))
            END
        )
        AS decimal(10,4)
    ) AS avg_repeat_rate_6m,

    CAST(
        AVG(
            CASE
                WHEN FirstOrderDate <= DATEADD(MONTH, -12, CAST(GETDATE() AS date))
                THEN CAST(repeat_12m AS decimal(10,4))
            END
        )
        AS decimal(10,4)
    ) AS avg_repeat_rate_12m

FROM customer_repeat;
GO


/* ===========================================================================
   2. PURCHASE SEQUENCE / NEXT PURCHASE ANALYSIS
   View: project.VIEW_customer_purchase_sequence

   Purpose:
   Identify which product subcategories are most frequently purchased in the
   order immediately following an order containing a given subcategory.

   Logic:

      Customer orders
            |
            v
      Current order -> Next order
            |
            v
      Subcategories in both orders
            |
            v
      Previous Subcategory -> Next Subcategory
            |
            v
      Number of next orders
      Number of customers
      Average days to next order
      Transition rate

   Transition rate:
       distinct next orders containing Y
       ---------------------------------
       all distinct next orders after X

   Because an order can contain multiple subcategories, one order can
   contribute to multiple subcategory transitions.
=========================================================================== */

CREATE OR ALTER VIEW project.VIEW_customer_purchase_sequence AS

/* Identify each customer's immediately following order. */
WITH order_sequence AS (
    SELECT
        CustomerID,
        SalesOrderID,
        OrderDate,
        LEAD(SalesOrderID) OVER (
            PARTITION BY CustomerID
            ORDER BY OrderDate ASC
        ) AS NextSalesOrderID,
        LEAD(OrderDate) OVER (
            PARTITION BY CustomerID
            ORDER BY OrderDate ASC
        ) AS NextOrderDate
    FROM project.Salesorderheader
),

/* Create one distinct row for every Order × Product Subcategory combination. */
subcategory_order AS (
    SELECT DISTINCT
        so.SalesOrderID,
        pc.subcategory
    FROM project.Salesorderheader AS so
    INNER JOIN project.Salesorderdetail AS st
        ON so.SalesOrderID = st.SalesOrderID
    INNER JOIN project.dimensioni_prod_cat AS pc
        ON st.ProductID = pc.productid
),

/* Match the subcategories of the current order with those of the next order. */
transitions AS (
    SELECT
        o.CustomerID,
        o.SalesOrderID,
        o.NextSalesOrderID,
        a.subcategory AS prev_subcategory,
        b.subcategory AS next_subcategory,
        DATEDIFF(day, o.OrderDate, o.NextOrderDate) AS DaysBetweenPurchases
    FROM order_sequence AS o
    INNER JOIN subcategory_order AS a
        ON o.SalesOrderID = a.SalesOrderID
    INNER JOIN subcategory_order AS b
        ON o.NextSalesOrderID = b.SalesOrderID
    WHERE o.NextSalesOrderID IS NOT NULL
),

/* Aggregate each Previous Subcategory -> Next Subcategory combination. */
transition_statistics AS (
    SELECT
        prev_subcategory,
        next_subcategory,
        COUNT(DISTINCT NextSalesOrderID) AS num_next_orders,
        COUNT(DISTINCT CustomerID) AS num_customers,
        AVG(DaysBetweenPurchases) AS avgdays_cons_orders
    FROM transitions
    GROUP BY
        prev_subcategory,
        next_subcategory
),

/* Calculate the total number of next orders for each starting subcategory. */
total_next_orders AS (
    SELECT
        prev_subcategory,
        COUNT(DISTINCT NextSalesOrderID) AS TotalNextOrders
    FROM transitions
    GROUP BY prev_subcategory
)

/* Calculate the transition rate used by the Power BI next-purchase analysis. */
SELECT
    s.*,
    t.TotalNextOrders,
    CAST(
        CAST(s.num_next_orders AS decimal(10,4))
        / NULLIF(t.TotalNextOrders, 0)
        AS decimal(10,4)
    ) AS transition_rate
FROM transition_statistics AS s
INNER JOIN total_next_orders AS t
    ON s.prev_subcategory = t.prev_subcategory;
GO


/* ===========================================================================
   3. PURCHASE FREQUENCY BY TERRITORY
   View: project.VIEW_purchase_frequency

   Purpose:
   Describe customer purchasing cadence by sales territory.

   KPIs:
   - TotalCustomers
   - AverageOrdersPerCustomer
   - AverageDaysBetweenOrders
   - MedianDays_betweenOrders
   - P75
   - P90

   Logic:

      Customer orders
            |
            v
      Previous order date (LAG)
            |
            v
      Days between consecutive orders
            |
            +-----------------------+
            |                       |
            v                       v
      Average metrics        Distribution metrics
                              Median / P75 / P90
            |                       |
            +-----------+-----------+
                        |
                        v
                 Territory summary

   Percentiles provide a more complete view of purchasing cadence than the
   average alone, especially when the distribution contains long intervals
   between purchases.
=========================================================================== */

CREATE OR ALTER VIEW project.VIEW_purchase_frequency AS

/* Retrieve the previous order date for every customer order. */
WITH previous_order AS (
    SELECT
        CustomerID,
        SalesOrderID,
        OrderDate,
        LAG(OrderDate) OVER (
            PARTITION BY CustomerID
            ORDER BY OrderDate
        ) AS PreviousOrderDate
    FROM project.Salesorderheader
),

/* Calculate days between consecutive purchases and attach the territory. */
purchase_intervals AS (
    SELECT
        a.*,
        c.Name,
        DATEDIFF(day, a.PreviousOrderDate, a.OrderDate) AS DaysBetweenOrders
    FROM previous_order AS a
    INNER JOIN project.Salesorderheader AS b
        ON a.SalesOrderID = b.SalesOrderID
    INNER JOIN project.Territory_prj AS c
        ON b.TerritoryID = c.TerritoryID
    WHERE a.PreviousOrderDate IS NOT NULL
),

/* Count total orders placed by each customer. */
customer_order_count AS (
    SELECT
        CustomerID,
        COUNT(*) AS NumberOfOrders
    FROM project.Salesorderheader
    GROUP BY CustomerID
),

/* Calculate territory-level average purchase-frequency indicators. */
territory_summary AS (
    SELECT
        pi.Name,
        COUNT(DISTINCT pi.CustomerID) AS TotalCustomers,
        AVG(coc.NumberOfOrders) AS AverageOrdersPerCustomer,
        AVG(pi.DaysBetweenOrders) AS AverageDaysBetweenOrders
    FROM purchase_intervals AS pi
    INNER JOIN customer_order_count AS coc
        ON pi.CustomerID = coc.CustomerID
    GROUP BY pi.Name
),

/* Add median and upper percentiles of days between consecutive purchases. */
purchase_distribution AS (
    SELECT DISTINCT
        a.*,
        b.MedianDays_betweenOrders,
        b.P75,
        b.P90
    FROM territory_summary AS a
    INNER JOIN (
        SELECT
            Name,
            PERCENTILE_CONT(0.50) WITHIN GROUP (
                ORDER BY DaysBetweenOrders
            ) OVER (
                PARTITION BY Name
            ) AS MedianDays_betweenOrders,

            PERCENTILE_CONT(0.75) WITHIN GROUP (
                ORDER BY DaysBetweenOrders
            ) OVER (
                PARTITION BY Name
            ) AS P75,

            PERCENTILE_CONT(0.90) WITHIN GROUP (
                ORDER BY DaysBetweenOrders
            ) OVER (
                PARTITION BY Name
            ) AS P90

        FROM purchase_intervals
    ) AS b
        ON a.Name = b.Name
)

SELECT *
FROM purchase_distribution;
GO
