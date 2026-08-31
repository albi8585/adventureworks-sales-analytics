/*
===============================================================================
 AdventureWorks Sales Analytics
 POWER BI FACT VIEW
 View: project.VIEW_orders_detailPB
===============================================================================

Purpose:
- Create the main fact-level reporting view used by Power BI.
- Preserve the maximum available granularity by starting from SalesOrderDetail.
- Enrich each order-detail row with order-header attributes.
- Attach the historical product cost valid on the order date.
- Calculate product-level gross margin and margin percentage.

Data flow:

  project.Salesorderdetail
            |
            +----------------------+
            |                      |
            v                      v
  project.Salesorderheader   project.productcosthistory
            |                      |
            +----------+-----------+
                       |
                       v
              Enriched order detail
                       |
                       v
              Margin calculations
                       |
                       v
             Power BI fact view

Grain:
- One row per SalesOrderDetail record.

Historical cost matching:
- ProductID must match.
- OrderDate must fall between StartDate and EndDate.
- EndDate = NULL represents the currently active cost record.

===============================================================================
*/

USE AdventureWorks2022;
GO


/* ===========================================================================
   Create the Power BI fact view.

   The view starts from SalesOrderDetail to preserve transaction-level
   granularity, then enriches each row with order-level attributes and the
   historical StandardCost valid on the order date.
=========================================================================== */

CREATE OR ALTER VIEW project.VIEW_orders_detailPB AS

WITH enriched_order_details AS (

    SELECT
        a.*,
        b.OrderDate,
        b.DueDate,
        b.ShipDate,
        b.OnlineOrderFlag,
        b.CustomerID,
        c.StandardCost,
        b.SalesPersonID,
        b.TerritoryID,
        b.modified_date

    FROM project.Salesorderdetail AS a

    INNER JOIN project.Salesorderheader AS b
        ON a.SalesOrderID = b.SalesOrderID

    INNER JOIN project.productcosthistory AS c
        ON a.ProductID = c.ProductID
       AND b.OrderDate >= c.StartDate
       AND (
            b.OrderDate <= c.EndDate
            OR c.EndDate IS NULL
       )
)

/* ---------------------------------------------------------------------------
   Margin calculations

   Product margin:
       LineTotal - (StandardCost * OrderQty)

   Margin percentage:
       Product Margin / LineTotal * 100
--------------------------------------------------------------------------- */

SELECT
    *,
    (
        LineTotal - (StandardCost * OrderQty)
    ) AS margine_prodotto_ordine,

    (
        CAST(
            (LineTotal - (StandardCost * OrderQty)) * 100
            AS decimal(10,2)
        )
        / LineTotal
    ) AS pct_margine_prodotto_ordine

FROM enriched_order_details;
GO
