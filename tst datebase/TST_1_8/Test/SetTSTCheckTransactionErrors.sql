--===================================================================
-- FILE: SetTSTCheckTransactionErrors.sql
-- This script will setup one of the databases used to test the 
-- TST infrastructure.
-- Suites and tests contained here will be fed into TST.
-- The tests here are focused on scenarios where the tested 
-- stored procedures put transactions in an uncommitable state or close transactions.
-- ==================================================================

USE tempdb
GO

-- =======================================================================
-- Creates the TSTCheckTransactionErrors Database. If already exists then drops it first.
-- =======================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckTransactionErrors')
BEGIN
   DROP DATABASE TSTCheckTransactionErrors
END

CREATE DATABASE TSTCheckTransactionErrors
GO

USE TSTCheckTransactionErrors
GO


-- =======================================================================
-- TSTConfig. TST will call this at the start of the test session 
-- to allow the test client to configure TST parameters
-- =======================================================================
CREATE PROCEDURE dbo.TSTConfig
AS
BEGIN
   EXEC TST.Utils.SetConfiguration @ParameterName='UseTSTRollback', @ParameterValue='0', @Scope='Test' , @ScopeValue='SQLTest_SuiteTriggerWithErrorNoRollback#Test'
   EXEC TST.Utils.SetConfiguration @ParameterName='UseTSTRollback', @ParameterValue='0', @Scope='Test' , @ScopeValue='SQLTest_SuiteInvalidTranNoRollback#Test'
END
GO

-- =======================================================================
-- TABLE: TestTableTRG1
-- This table will contain test entries that are used to test 
-- triggers that raise errors.
-- =======================================================================
CREATE TABLE dbo.TestTableTRG1 
(
   EntryId        int NOT NULL IDENTITY(1,1),   -- Identifies the test entry. 
   EntryValue     varchar(1000) NOT NULL
)
GO

-- =======================================================================
-- TABLE: TriggerLog
-- This table will contain entries inserted by triggers. 
-- Used to test transaction inside triggers.
-- =======================================================================
CREATE TABLE dbo.TriggerLog
(
   EntryId     int NOT NULL IDENTITY(1,1),   -- Identifies the test entry. 
   LogMessage  varchar(1000) NOT NULL
)
GO

CREATE TRIGGER TR_TestTableTRG1_NoTransactions ON dbo.TestTableTRG1 AFTER INSERT, UPDATE, DELETE 
AS

   DECLARE @ValueBefore       varchar(1000)
   DECLARE @ValueAfter        varchar(1000)
   DECLARE @TriggerMessage    varchar(1000)
   
   SELECT @ValueBefore = Deleted.EntryValue FROM Deleted
   SELECT @ValueAfter  = Inserted.EntryValue FROM Inserted
   
   SET @TriggerMessage = 'TestTableTRG3. Value before: ' + ISNULL(@ValueBefore, 'null') + '. Value after: ' + ISNULL(@ValueAfter, 'null')

   INSERT INTO dbo.TriggerLog(LogMessage) VALUES (@TriggerMessage)

   RAISERROR('Test error', 16, 1)
GO

CREATE PROCEDURE dbo.TriggerWithError
   @TestValue     varchar(1000)
AS
BEGIN

   -- The trigger will raise an error
   INSERT INTO dbo.TestTableTRG1(EntryValue) VALUES (@TestValue)

END
GO

-- =======================================================================
-- START ~ TRIGGER/RAISERROR - Multiple tests. 
-- =======================================================================

-- =======================================================================
-- This is the case where one of the tested stored procedures involves 
-- a trigger that uses a RAISERROR. The error is expected
-- =======================================================================

CREATE PROCEDURE dbo.SQLTest_TriggerWithError
AS
BEGIN

   EXEC TST.Assert.LogInfo 'This is SQLTest_TriggerWithError'

   EXEC TST.Assert.RegisterExpectedError 
      @ContextMessage               = 'A trigger will raise an error',
      @ExpectedErrorMessage         = 'Test error',
      @ExpectedErrorProcedure       = 'TR_TestTableTRG1_NoTransactions',
      @ExpectedErrorNumber          = 50000
      
   EXEC dbo.TriggerWithError 'abc'
   EXEC TST.Assert.LogInfo  'This log should not be executed'

END
GO

-- =======================================================================
-- This is the case where one of the tested stored procedures involves 
-- a trigger that uses a RAISERROR. The error is expected however we also 
-- have a teardown. Because the transaction is in an uncommittable state 
-- the teardown cannot be executed inside the transaction.
-- =======================================================================

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_SuiteTriggerWithErrorAndTeardown
AS
BEGIN
   EXEC TST.Assert.LogInfo  'This is SQLTest_TEARDOWN_SuiteTriggerWithErrorAndTeardown'
END
GO

CREATE PROCEDURE dbo.SQLTest_SuiteTriggerWithErrorAndTeardown#Test
AS
BEGIN

   EXEC TST.Assert.LogInfo 'This is SQLTest_SuiteTriggerWithErrorAndTeardown#Test'

   EXEC TST.Assert.RegisterExpectedError 
      @ContextMessage               = 'A trigger will raise an error',
      @ExpectedErrorMessage         = 'Test error',
      @ExpectedErrorProcedure       = 'TR_TestTableTRG1_NoTransactions',
      @ExpectedErrorNumber          = 50000
      
   EXEC dbo.TriggerWithError 'abc'
   EXEC TST.Assert.LogInfo  'This log should not be executed'

END
GO

-- =======================================================================
-- This is the case where one of the tested stored procedures involves 
-- a trigger that uses a RAISERROR. The error is expected. The auto-rollback 
-- is disabled to prevent the scenario where the transaction reaches an 
-- uncommittable state.
-- =======================================================================

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_SuiteTriggerWithErrorNoRollback
AS
BEGIN

   DECLARE @RowCount int

   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG1 WHERE EntryValue = 'SQLTest_SuiteTriggerWithErrorNoRollback#Test'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_SuiteTriggerWithErrorNoRollback. Row count in TestTableTRG1.', 0, @RowCount

   SELECT @RowCount = COUNT(*) FROM dbo.TriggerLog WHERE LogMessage like '%SQLTest_SuiteTriggerWithErrorNoRollback#Test%'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_SuiteTriggerWithErrorNoRollback. Row count in TriggerLog.', 0, @RowCount

   DELETE FROM dbo.TriggerLog WHERE LogMessage = 'SQLTest_SuiteTriggerWithErrorNoRollback#Test'

END
GO

CREATE PROCEDURE dbo.SQLTest_SuiteTriggerWithErrorNoRollback#Test
AS
BEGIN

   EXEC TST.Assert.LogInfo 'This is SQLTest_SuiteTriggerWithErrorNoRollback#Test'

   EXEC TST.Assert.RegisterExpectedError 
      @ContextMessage               = 'A trigger will raise an error',
      @ExpectedErrorMessage         = 'Test error',
      @ExpectedErrorProcedure       = 'TR_TestTableTRG1_NoTransactions',
      @ExpectedErrorNumber          = 50000
      
   EXEC dbo.TriggerWithError 'SQLTest_SuiteTriggerWithErrorNoRollback#Test'
   EXEC TST.Assert.LogInfo  'This log will be executed'

END
GO

-- =======================================================================
-- END ~ TRIGGER/RAISERROR
-- =======================================================================

-- =======================================================================
-- START ~ TRANSACTION in invalid state - Multiple tests. ~
-- =======================================================================

-- =======================================================================
-- This is the case where the tested stored procedures places the current 
-- transaction in an uncommittable state. The error is expected. 
-- No teardown is defined.
-- =======================================================================

CREATE PROCEDURE dbo.PlaceTranInvalidState
AS
BEGIN
   DECLARE @TestValue int
   SELECT @TestValue = CAST ('abc' AS int)
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Test_PlaceTranInvalidState
AS
BEGIN

   EXEC TST.Assert.RegisterExpectedError 
      @ContextMessage               = 'An invalid cast will raise an error',
      @ExpectedErrorProcedure       = 'PlaceTranInvalidState',
      @ExpectedErrorNumber          = 245

   EXEC TST.Assert.LogInfo 'This is SQLTest_Proc_Test_PlaceTranInvalidState'

   EXEC dbo.PlaceTranInvalidState 

   EXEC TST.Assert.LogInfo  'This log should not be executed'
   
END
GO

-- =======================================================================
-- This is the case where the tested stored procedures places the current 
-- transaction in an uncommittable state. The error is expected. 
-- A teardown is defined.
-- =======================================================================

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_SuiteInvalidTran
AS
BEGIN

   EXEC TST.Assert.LogInfo  'This is SQLTest_TEARDOWN_SuiteInvalidTran'

END
GO

CREATE PROCEDURE dbo.SQLTest_SuiteInvalidTran#Test
AS
BEGIN

   EXEC TST.Assert.RegisterExpectedError 
      @ContextMessage               = 'An invalid cast will raise an error',
      @ExpectedErrorProcedure       = 'PlaceTranInvalidState',
      @ExpectedErrorNumber          = 245

   EXEC TST.Assert.LogInfo 'This is SQLTest_SuiteInvalidTran#Test'

   EXEC dbo.PlaceTranInvalidState 

   EXEC TST.Assert.LogInfo  'This log should not be executed'
   
END
GO

-- =======================================================================
-- This is the case where the tested stored procedures places the current 
-- transaction in an uncommittable state. The error is expected. 
-- A teardown is defined. Auto-rollback is disabled.
-- =======================================================================

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_SuiteInvalidTranNoRollback
AS
BEGIN

   EXEC TST.Assert.LogInfo  'This is SQLTest_TEARDOWN_SuiteInvalidTranNoRollback'

END
GO

CREATE PROCEDURE dbo.SQLTest_SuiteInvalidTranNoRollback#Test
AS
BEGIN

   EXEC TST.Assert.RegisterExpectedError 
      @ContextMessage               = 'An invalid cast will raise an error',
      @ExpectedErrorProcedure       = 'PlaceTranInvalidState',
      @ExpectedErrorNumber          = 245

   EXEC TST.Assert.LogInfo 'This is SQLTest_SuiteInvalidTranNoRollback#Test'

   EXEC dbo.PlaceTranInvalidState 

   EXEC TST.Assert.LogInfo  'This log should not be executed'
   
END
GO

-- =======================================================================
-- END ~ TRANSACTION in invalid state. ~
-- =======================================================================

USE tempdb
GO

