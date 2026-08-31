/*
===============================================================================
 AdventureWorks Sales Analytics
 STORED PROCEDURE - RESET HISTORICAL TABLES FOR TESTING
 Original procedure: dbo.reset_historical_tables_for_test
===============================================================================

Purpose:
- Remove previously loaded simulated orders from the historical project tables.
- Restore project.orders_temp.processed to 0.
- Allow the same staging dataset to be loaded again during pipeline testing.

Test reset flow:

  dbo.orderheader_temp
          |
          +--> SalesOrderID list
          |
          +------------------------------+
          |                              |
          v                              v
  DELETE matching details        DELETE matching headers
          |                              |
          +---------------+--------------+
                          |
                          v
              orders_temp.processed = 0
                          |
                          v
                  Ready for retest

Important:
- Order details are deleted before order headers to preserve referential
  integrity.

===============================================================================
*/

USE [AdventureWorks2022];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

ALTER PROCEDURE [dbo].[reset_historical_tables_for_test]
AS
BEGIN
    SET NOCOUNT ON;

    /* The reset can run only when the helper table from a daily load exists. */
    IF OBJECT_ID('dbo.orderheader_temp', 'U') IS NOT NULL
    BEGIN

        /* -------------------------------------------------------------------
           1. REMOVE TEST ORDER DETAILS
        ------------------------------------------------------------------- */
        DECLARE @count_detail INT;

        SELECT @count_detail = COUNT(*)
        FROM project.Salesorderdetail;

        PRINT CONCAT(
            'SalesOrderDetail rows before test reset: ',
            @count_detail
        );

        DELETE c
        FROM project.Salesorderdetail AS c
        INNER JOIN dbo.orderheader_temp AS o
            ON c.SalesOrderID = o.SalesOrderID;

        SELECT @count_detail = COUNT(*)
        FROM project.Salesorderdetail;

        PRINT CONCAT(
            'SalesOrderDetail rows after test reset: ',
            @count_detail
        );


        /* -------------------------------------------------------------------
           2. REMOVE TEST ORDER HEADERS

           Header rows are removed only after the related details have been
           deleted.
        ------------------------------------------------------------------- */
        DECLARE @count_header INT;

        SELECT @count_header = COUNT(*)
        FROM project.Salesorderheader;

        PRINT CONCAT(
            'SalesOrderHeader rows before test reset: ',
            @count_header
        );

        DELETE c
        FROM project.Salesorderheader AS c
        INNER JOIN dbo.orderheader_temp AS o
            ON c.SalesOrderID = o.SalesOrderID;

        SELECT @count_header = COUNT(*)
        FROM project.Salesorderheader;

        PRINT CONCAT(
            'SalesOrderHeader rows after test reset: ',
            @count_header
        );


        /* -------------------------------------------------------------------
           3. RE-ENABLE THE STAGING DATA FOR ANOTHER TEST LOAD
        ------------------------------------------------------------------- */
        UPDATE project.orders_temp
        SET processed = 0;

        PRINT 'Test reset completed. Staging orders are available for reloading.';

    END
    ELSE
    BEGIN

        PRINT 'No test reset performed: dbo.orderheader_temp does not exist.';

    END;
END;
GO
