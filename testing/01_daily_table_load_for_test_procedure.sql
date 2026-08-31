/*
===============================================================================
 AdventureWorks Sales Analytics
 STORED PROCEDURE - DAILY TABLE LOAD
 Original procedure: dbo.daily_table_load
===============================================================================

Purpose:
- Build the daily order-header dataset from the staging tables.
- Prevent duplicate loading of the same simulated orders.
- Append new order headers and order details to the historical project tables.
- Mark the staging orders as processed after a successful load.

Data flow:

  project.orders_temp
          +
  project.daily_orderdetails_temp
          |
          v
  dbo.orderheader_temp
          |
          +----------------------+
          |                      |
          v                      v
  project.Salesorderheader   project.Salesorderdetail
          |
          v
  project.orders_temp.processed = 1

===============================================================================
*/

USE [AdventureWorks2022];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

ALTER PROCEDURE [dbo].[daily_table_load]
AS
BEGIN
    SET NOCOUNT ON;

    /* -----------------------------------------------------------------------
       1. CLEAN PREVIOUS HELPER TABLE

       Remove the helper table left by a previous execution, if present.
       This table contains the reconstructed headers for the current daily load.
    ----------------------------------------------------------------------- */
    IF OBJECT_ID('dbo.orderheader_temp', 'U') IS NOT NULL
        DROP TABLE dbo.orderheader_temp;


    /* -----------------------------------------------------------------------
       2. COUNT CURRENT HISTORICAL ORDER HEADERS
    ----------------------------------------------------------------------- */
    DECLARE @orderheader INT;

    SELECT @orderheader = COUNT(*)
    FROM project.Salesorderheader;

    PRINT CONCAT('SalesOrderHeader rows before daily load: ', @orderheader);


    /* -----------------------------------------------------------------------
       3. CHECK WHETHER DAILY STAGING DATA EXISTS

       If project.orders_temp does not exist, there are no simulated orders
       available for loading.
    ----------------------------------------------------------------------- */
    IF OBJECT_ID('project.orders_temp', 'U') IS NOT NULL
    BEGIN

        /* -------------------------------------------------------------------
           4. BUILD THE DAILY ORDER-HEADER DATASET

           Sources:
             project.orders_temp
                    +
             project.daily_orderdetails_temp
                    |
                    v
             aggregate LineTotal by SalesOrderID
                    |
                    v
             rebuild order-header structure
                    |
                    v
             dbo.orderheader_temp
        ------------------------------------------------------------------- */

        WITH aggrega AS (
            SELECT
                SalesOrderID,
                SUM(LineTotal) AS subtotal
            FROM project.daily_orderdetails_temp
            GROUP BY SalesOrderID
        ),
        creo_orderheader AS (
            SELECT
                ot.SalesOrderID,
                OrderDate,
                DueDate,
                ShipDate,
                OnlineOrderFlag,
                CustomerID,
                SalesPersonID,
                TerritoryID,
                subtotal
            FROM aggrega AS ag
            INNER JOIN project.orders_temp AS ot
                ON ag.SalesOrderID = ot.SalesOrderID
        )
        SELECT
            SalesOrderID,
            OrderDate,
            DueDate,
            ShipDate,
            OnlineOrderFlag,
            CustomerID,
            SalesPersonID,
            TerritoryID,
            subtotal
        INTO dbo.orderheader_temp
        FROM creo_orderheader;


        /* -------------------------------------------------------------------
           5. DUPLICATE-LOAD CHECK

           Stop the procedure if any SalesOrderID from the current staging load
           is already present in the historical order-header table.
        ------------------------------------------------------------------- */
        IF EXISTS (
            SELECT 1
            FROM dbo.orderheader_temp AS ot
            INNER JOIN project.Salesorderheader AS h
                ON ot.SalesOrderID = h.SalesOrderID
        )
        BEGIN
            THROW 50001,
                  'Error: these orders have already been loaded. Run the test reset procedure before reloading them.',
                  1;
        END;


        /* -------------------------------------------------------------------
           6. LOAD DAILY ORDER HEADERS INTO THE HISTORICAL TABLE
        ------------------------------------------------------------------- */
        INSERT INTO project.Salesorderheader (
            SalesOrderID,
            OrderDate,
            DueDate,
            ShipDate,
            OnlineOrderFlag,
            CustomerID,
            SalesPersonID,
            TerritoryID,
            SubTotal
        )
        SELECT
            SalesOrderID,
            OrderDate,
            DueDate,
            ShipDate,
            OnlineOrderFlag,
            CustomerID,
            SalesPersonID,
            TerritoryID,
            SubTotal
        FROM dbo.orderheader_temp;

        PRINT 'Daily SalesOrderHeader load completed.';

        SELECT @orderheader = COUNT(*)
        FROM project.Salesorderheader;

        PRINT CONCAT('SalesOrderHeader rows after daily load: ', @orderheader);


        /* -------------------------------------------------------------------
           7. LOAD DAILY ORDER DETAILS INTO THE HISTORICAL TABLE

           Only detail rows whose SalesOrderID belongs to the reconstructed
           daily header dataset are inserted.
        ------------------------------------------------------------------- */
        DECLARE @numorder_details INT;

        SELECT @numorder_details = COUNT(SalesOrderID)
        FROM project.Salesorderdetail;

        PRINT CONCAT(
            'SalesOrderDetail rows before daily load: ',
            @numorder_details
        );

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
            od.SalesOrderID,
            OrderQty,
            ProductID,
            UnitPrice,
            LineTotal,
            UnitPriceDiscount,
            SpecialOfferID
        FROM project.daily_orderdetails_temp AS od
        INNER JOIN dbo.orderheader_temp AS ot
            ON od.SalesOrderID = ot.SalesOrderID;

        SELECT @numorder_details = COUNT(SalesOrderID)
        FROM project.Salesorderdetail;

        PRINT CONCAT(
            'SalesOrderDetail rows after daily load: ',
            @numorder_details
        );


        /* -------------------------------------------------------------------
           8. MARK STAGING ORDERS AS PROCESSED

           processed = 0 -> waiting for the daily load
           processed = 1 -> already loaded

           This flag prevents the automation procedure from processing the
           same staging data again.
        ------------------------------------------------------------------- */
        UPDATE project.orders_temp
        SET processed = 1;

        PRINT 'project.orders_temp processed flag updated to 1.';

    END;
END;
GO
