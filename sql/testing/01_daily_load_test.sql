/*
===============================================================================
 AdventureWorks Sales Analytics
 DAILY LOAD TEST RUNNER
===============================================================================

Purpose:
- Execute the daily loading procedure in a controlled test.
- Verify that simulated staging data can be appended to the historical tables.
- Restore the affected historical tables after validation.
- Keep the same staging dataset available for another test cycle.

Test flow:

  Daily staging data
         |
         v
  dbo.daily_table_load
         |
         v
  Validate historical load
         |
         v
  dbo.reset_historical_tables_for_test
         |
         v
  Historical tables restored for another test

Note:
- Run this script only in the development/test workflow.
===============================================================================
*/

USE AdventureWorks2022;
GO

EXEC dbo.daily_table_load;
GO

EXEC dbo.reset_historical_tables_for_test;
GO
