/*
===============================================================================
 AdventureWorks Sales Analytics
 04 - CREATE ACTION MONITORING VIEW
===============================================================================

Purpose:
- Build the dataset consumed by the Power BI Action Monitoring page.
- Combine the frozen Country x Subcategory snapshot with live sales results.
- Recalculate current-year revenue as new simulated transactions are loaded.
- Build the current revenue goal from the full previous-year revenue baseline,
  scaled to elapsed current-year days and multiplied by the 1.3012 growth rate.

Logic:
  1) CurrentData aggregates live order-detail data by Country and Subcategory.
  2) CurrentRevenue covers January 1 of the current year through today.
  3) PreviousYearRevenue covers the complete previous calendar year.
  4) The snapshot table supplies the original baseline and priority assigned
     when the commercial action was opened.
  5) CurrentGoalAdOggi converts the previous-year annual revenue into a daily
     average, projects it over elapsed current-year days and applies 1.3012.

The LEFT JOIN preserves every monitored Country x Subcategory combination even
when no matching current sales are available.
===============================================================================
*/

USE AdventureWorks2022;
GO

CREATE OR ALTER VIEW Project.VW_ActionMonitoring
AS

WITH CurrentData AS
(
    SELECT
        t.Name AS Country,
        p.Subcategory,

        --------------------------------------------------
        -- CURRENT REVENUE
        -- Fatturato anno corrente fino ad oggi
        --------------------------------------------------
        SUM(
            CASE
                WHEN v.OrderDate >=
                     DATEFROMPARTS(YEAR(GETDATE()), 1, 1)

                 AND v.OrderDate <
                     DATEADD(
                        DAY,
                        1,
                        CAST(GETDATE() AS date)
                     )

                THEN v.LineTotal
                ELSE 0
            END
        ) AS CurrentRevenue,


        --------------------------------------------------
        -- PREVIOUS YEAR REVENUE
        -- Fatturato dell'intero anno precedente
        --------------------------------------------------
        SUM(
            CASE
                WHEN v.OrderDate >=
                     DATEFROMPARTS(YEAR(GETDATE()) - 1, 1, 1)

                 AND v.OrderDate <
                     DATEFROMPARTS(YEAR(GETDATE()), 1, 1)

                THEN v.LineTotal
                ELSE 0
            END
        ) AS PreviousYearRevenue

    FROM Project.VIEW_orders_detailPB AS v

    INNER JOIN Project.dimensioni_prod_cat_prj AS p
        ON v.ProductID = p.ProductID

    INNER JOIN Project.Territory_prj AS t
        ON v.TerritoryID = t.TerritoryID

    GROUP BY
        t.Name,
        p.Subcategory
)


SELECT

    --------------------------------------------------
    -- SNAPSHOT
    --------------------------------------------------
    s.SnapshotDate,
    s.Country,
    s.Subcategory,
    s.PriorityType,

    s.SnapshotRevenue,
    s.CurrentSnapshotGoal,
    s.PercCurrentSnapshotGoal,
    s.DeltaCurrentSnapshotGoal,


    --------------------------------------------------
    -- CURRENT REVENUE
    --------------------------------------------------
    c.CurrentRevenue,


    --------------------------------------------------
    -- CURRENT GOAL AD OGGI
    --
    -- Previous Year Revenue
    -- / giorni anno precedente
    -- * giorni trascorsi anno corrente
    -- * Growth Rate 1.3012
    --------------------------------------------------
    (
        c.PreviousYearRevenue
        /
        NULLIF(
            DATEDIFF(
                DAY,
                DATEFROMPARTS(YEAR(GETDATE()) - 1, 1, 1),
                DATEFROMPARTS(YEAR(GETDATE()), 1, 1)
            ),
            0
        )
    )
    *
    (
        DATEDIFF(
            DAY,
            DATEFROMPARTS(YEAR(GETDATE()), 1, 1),
            CAST(GETDATE() AS date)
        ) + 1
    )
    * 1.3012
        AS CurrentGoalAdOggi


FROM Project.ActionMonitoringSnapshot AS s

LEFT JOIN CurrentData AS c
    ON  c.Country = s.Country
    AND c.Subcategory = s.Subcategory;

GO