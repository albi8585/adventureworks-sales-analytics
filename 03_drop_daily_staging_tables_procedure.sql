/*
===============================================================================
 AdventureWorks Sales Analytics
 STORED PROCEDURE - DROP DAILY STAGING TABLES
 Original procedure: dbo.droptables
===============================================================================

Purpose:
- Remove the two physical staging tables generated for a simulated sales day.
- This procedure is called after the daily data has been successfully loaded.

Cleanup flow:

  project.orders_temp --------------------+
                                          |
                                          +--> DROP if present
                                          |
  project.daily_orderdetails_temp --------+

===============================================================================
*/

USE [AdventureWorks2022];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

ALTER PROCEDURE [dbo].[droptables]
AS
BEGIN
    SET NOCOUNT ON;

    /* Remove daily order-header staging data. */
    IF OBJECT_ID('project.orders_temp', 'U') IS NOT NULL
        DROP TABLE project.orders_temp;

    /* Remove daily order-detail staging data. */
    IF OBJECT_ID('project.daily_orderdetails_temp', 'U') IS NOT NULL
        DROP TABLE project.daily_orderdetails_temp;

END;
GO
