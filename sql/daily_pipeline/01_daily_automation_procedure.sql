/*
===============================================================================
 AdventureWorks Sales Analytics
 STORED PROCEDURE - DAILY LOAD AUTOMATION
 Original procedure: dbo.daily_load_automation
===============================================================================

Purpose:
- Check whether today's simulated orders are waiting to be processed.
- Run the daily historical-table load only when eligible rows exist.
- Remove the daily staging tables after a successful load.
- Return an informational message that can be read from SQL Server Agent.

Automation flow:

  project.orders_temp
          |
          v
  processed = 0
  AND modified_date = today?
          |
      +---+---+
      |       |
     YES      NO
      |       |
      v       v
  Daily load  No action
      |
      v
  Drop staging tables
      |
      v
  Completion message

===============================================================================
*/

USE [AdventureWorks2022];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

ALTER PROCEDURE [dbo].[daily_load_automation]
AS
BEGIN
    SET NOCOUNT ON;

    /* Count today's unprocessed staging orders. */
    DECLARE @RigheDaCaricare INT;

    SELECT @RigheDaCaricare = COUNT(*)
    FROM project.orders_temp
    WHERE processed = 0
      AND CAST(modified_date AS date) = CAST(GETDATE() AS date);

    IF @RigheDaCaricare > 0
    BEGIN

        /* Load the daily staging data into the historical project tables. */
        EXEC dbo.daily_table_load;

  
        RAISERROR(
            'Daily load completed. Eligible staging rows found: %d',
            10,
            1,
            @RigheDaCaricare
        ) WITH NOWAIT;

    END
    ELSE
    BEGIN

        RAISERROR(
            'No data available for today''s daily load.',
            10,
            1
        ) WITH NOWAIT;

    END;
END;
GO
