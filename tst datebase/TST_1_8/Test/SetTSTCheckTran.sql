--===================================================================
-- FILE: SetTSTCheckTran.sql
-- This script will setup one of the databases used to test the 
-- TST infrastructure.
-- Suites and tests contained here will be fed into TST.
-- The tests here are focused on scenarios where the tested 
-- stored procedures are using transactions.
-- ==================================================================

USE tempdb
GO

-- =======================================================================
-- Creates the TSTCheckTran Database. If already exists then drops it first.
-- =======================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckTran')
BEGIN
   DROP DATABASE TSTCheckTran
END

CREATE DATABASE TSTCheckTran
GO

USE TSTCheckTran
GO


-- =======================================================================
-- TSTConfig. TST will call this at the start of the test session 
-- to allow the test client to configure TST parameters
-- =======================================================================
CREATE PROCEDURE dbo.TSTConfig
AS
BEGIN
   EXEC TST.Utils.SetConfiguration @ParameterName='UseTSTRollback', @ParameterValue='0', @Scope='Suite', @ScopeValue='Proc_Test_TranRollbackSRDisabled'
   EXEC TST.Utils.SetConfiguration @ParameterName='UseTSTRollback', @ParameterValue='0', @Scope='Test' , @ScopeValue='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestB'
   EXEC TST.Utils.SetConfiguration @ParameterName='UseTSTRollback', @ParameterValue='0', @Scope='Test' , @ScopeValue='SQLTest_Proc_Test_TranBeginSRDisabled#Test'
   EXEC TST.Utils.SetConfiguration @ParameterName='UseTSTRollback', @ParameterValue='0', @Scope='Suite', @ScopeValue='Proc_Setup_TranRollbackSRDisabled'
   EXEC TST.Utils.SetConfiguration @ParameterName='UseTSTRollback', @ParameterValue='0', @Scope='Suite', @ScopeValue='Proc_Teardown_TranRollbackSRDisabled'
   EXEC TST.Utils.SetConfiguration @ParameterName='UseTSTRollback', @ParameterValue='0', @Scope='Test' , @ScopeValue='SQLTest_Trigger_Test_TranRollbackSRDisabled#Test'
   EXEC TST.Utils.SetConfiguration @ParameterName='UseTSTRollback', @ParameterValue='0', @Scope='Test' , @ScopeValue='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB'
   EXEC TST.Utils.SetConfiguration @ParameterName='UseTSTRollback', @ParameterValue='0', @Scope='Suite', @ScopeValue='Trigger_Setup_Multi_TranRollbackSRDisabled'
   EXEC TST.Utils.SetConfiguration @ParameterName='UseTSTRollback', @ParameterValue='0', @Scope='Suite', @ScopeValue='Trigger_Teardown_Multi_TranRollbackSRDisabled'
END
GO

-- =======================================================================
-- TABLE: TestTable
-- This table will contain test entries that are used to test transactions.
-- =======================================================================
CREATE TABLE dbo.TestTable(
   EntryId        int NOT NULL IDENTITY(1,1),   -- Identifies the test entry. 
   EntryValue     varchar(1000) NOT NULL
)
GO

-- =======================================================================
-- TABLE: TestTableTRG1
-- This table will contain test entries that are used to test 
-- triggers with transactions.
-- =======================================================================
CREATE TABLE dbo.TestTableTRG1 
(
   EntryId        int NOT NULL IDENTITY(1,1),   -- Identifies the test entry. 
   EntryValue     varchar(1000) NOT NULL
)
GO

-- =======================================================================
-- TABLE: TestTableTRG2
-- This table will contain test entries that are used to test 
-- triggers with transactions and rollback.
-- =======================================================================
CREATE TABLE dbo.TestTableTRG2 
(
   EntryId        int NOT NULL IDENTITY(1,1),   -- Identifies the test entry. 
   EntryValue     varchar(1000) NOT NULL
)
GO

-- =======================================================================
-- TABLE: TestTableTRG3
-- This table will contain test entries that are used to test 
-- triggers with transactions and commit.
-- =======================================================================
CREATE TABLE dbo.TestTableTRG3
(
   EntryId        int NOT NULL IDENTITY(1,1),   -- Identifies the test entry. 
   EntryValue     varchar(1000) NOT NULL
)
GO

-- =======================================================================
-- TABLE: TestTableTRG4
-- This table will contain test entries that are used to test 
-- triggers that open transactions 
-- =======================================================================
CREATE TABLE dbo.TestTableTRG4
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

-- =======================================================================
-- START ~ No Transactions case ~
-- This is the regular case where the tested stored procedures do not use 
-- transactions.
-- =======================================================================

CREATE PROCEDURE dbo.NoTransactionSProc
   @A          int,
   @B          int,
   @AddResult  int OUT
AS
BEGIN
   SET @AddResult = @A + @B
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Test_NoTransactions
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Test_NoTransactions'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Test_NoTransactions
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Test_NoTransactions'
END
GO

CREATE PROCEDURE dbo.SQLTest_Test_NoTransactions#Test
AS
BEGIN
   DECLARE @AddResult  int

   EXEC dbo.NoTransactionSProc 1, 2, @AddResult OUT
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Test_NoTransactions#Test', 3, @AddResult
END
GO

-- =======================================================================
-- END ~ No Transactions case ~
-- =======================================================================

-- =======================================================================
-- START ~ SAVE TRANSACTION / ROLLBACK TRANSACTION case ~
-- This is the case where the tested stored procedures uses transactions
-- and does a rollback but it uses save points
-- =======================================================================

CREATE PROCEDURE dbo.InsertTestEntryAndRollbackSavePoint
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN

   SAVE TRANSACTION T1
   INSERT INTO dbo.TestTable(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
   ROLLBACK TRANSACTION T1

END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Test_SavePointTransaction
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Test_SavePointTransaction'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Test_SavePointTransaction
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Test_SavePointTransaction'
END
GO

CREATE PROCEDURE dbo.SQLTest_Test_SavePointTransaction#Test
AS
BEGIN
   DECLARE @RowCount    int
   DECLARE @EntryId     int

   EXEC TST.Assert.LogInfo 'This is SQLTest_Test_SavePointTransaction#Test'
   EXEC dbo.InsertTestEntryAndRollbackSavePoint 'SQLTest_Test_SavePointTransaction#Test', @EntryId OUT

   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_TranRollback#Test', 0, @RowCount

END
GO

-- =======================================================================
-- END ~ SAVE TRANSACTION / ROLLBACK TRANSACTION case ~
-- =======================================================================

-- =======================================================================
-- START ~ TRANSACTION with ROLLBACK case ~
-- This is the case where the tested stored procedures uses a TRANSACTION 
-- and does a ROLLBACK.
-- =======================================================================

CREATE PROCEDURE dbo.InsertTestEntryAndRollback1
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   BEGIN TRANSACTION
   INSERT INTO dbo.TestTable(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
   ROLLBACK TRANSACTION
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Proc_Test_TranRollback
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Proc_Test_TranRollback'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Proc_Test_TranRollback
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Proc_Test_TranRollback'
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Test_TranRollback#Test
AS
BEGIN

   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_TranRollback#Test', 1, 1
   EXEC dbo.InsertTestEntryAndRollback1 'SQLTest_Proc_Test_TranRollback#Test', @EntryId OUT

   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryValue = 'SQLTest_Proc_Test_TranRollback#Test' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_TranRollback#Test', 0, @RowCount
   
END
GO

-- =======================================================================
-- END ~ TRANSACTION with ROLLBACK case ~
-- =======================================================================

-- =======================================================================
-- START ~ TRANSACTION with ROLLBACK and TST rollback disabled ~
-- This is the case where the tested stored procedures uses a TRANSACTION 
-- and does a ROLLBACK but TST rollback is disabled via TSTConfig.
-- =======================================================================

CREATE PROCEDURE dbo.InsertTestEntryAndRollback2
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   BEGIN TRANSACTION
   INSERT INTO dbo.TestTable(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
   ROLLBACK TRANSACTION
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Proc_Test_TranRollbackSRDisabled
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Proc_Test_TranRollbackSRDisabled'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Proc_Test_TranRollbackSRDisabled
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Proc_Test_TranRollbackSRDisabled'
END
GO


CREATE PROCEDURE dbo.SQLTest_Proc_Test_TranRollbackSRDisabled#Test
AS
BEGIN

   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is SQLTest_Proc_Test_TranRollbackSRDisabled#Test'
   EXEC dbo.InsertTestEntryAndRollback2 'SQLTest_Proc_Test_TranRollbackSRDisabled#Test', @EntryId OUT

   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryValue = 'SQLTest_Proc_Test_TranRollbackSRDisabled#Test' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_TranRollbackSRDisabled#Test', 0, @RowCount
   
END
GO

-- =======================================================================
-- END ~ TRANSACTION with ROLLBACK and TST rollback disabled ~
-- =======================================================================

-- =======================================================================
-- START ~ Multiple tests. One with TRANSACTION with ROLLBACK ~
-- This is the case where one of the tested stored procedures uses 
-- a TRANSACTION and does a ROLLBACK.
-- =======================================================================
CREATE PROCEDURE dbo.InsertTestEntryAndRollback3
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   BEGIN TRANSACTION
   INSERT INTO dbo.TestTable(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
   ROLLBACK TRANSACTION
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Proc_Test_Multi_TranRollback
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Proc_Test_Multi_TranRollback'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Proc_Test_Multi_TranRollback
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Proc_Test_Multi_TranRollback'
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Test_Multi_TranRollback#TestB
AS
BEGIN

   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_Multi_TranRollback#TestB #1', 1, 1
   
   EXEC dbo.InsertTestEntryAndRollback3 'SQLTest_Proc_Test_Multi_TranRollback#TestB', @EntryId OUT

   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryValue = 'SQLTest_Proc_Test_Multi_TranRollback#TestB' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_Multi_TranRollback#TestB #2', 0, @RowCount
   
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Test_Multi_TranRollback#TestA
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_Multi_TranRollback#TestA', 1, 1
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Test_Multi_TranRollback#TestC
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_Multi_TranRollback#TestC', 1, 1
END
GO

-- =======================================================================
-- END ~ Multiple tests. One with TRANSACTION with ROLLBACK and TST rollback disabled ~
-- =======================================================================

-- =======================================================================
-- START ~ Multiple tests. One with TRANSACTION with ROLLBACK and TST rollback disabled ~
-- This is the case where one of the tested stored procedures uses 
-- a TRANSACTION and does a ROLLBACK but TST rollback is disabled 
-- via TSTConfig.
-- =======================================================================

CREATE PROCEDURE dbo.InsertTestEntryAndRollback4
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   BEGIN TRANSACTION
   INSERT INTO dbo.TestTable(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
   ROLLBACK TRANSACTION
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Proc_Test_Multi_TranRollbackSRDisabled
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Proc_Test_Multi_TranRollbackSRDisabled'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Proc_Test_Multi_TranRollbackSRDisabled
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Proc_Test_Multi_TranRollbackSRDisabled'
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestB
AS
BEGIN

   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestB #1', 1, 1
   
   EXEC dbo.InsertTestEntryAndRollback4 'SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestB', @EntryId OUT

   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryValue = 'SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestB' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestB #2', 0, @RowCount
   
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestA
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestA', 1, 1
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestC
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestC', 1, 1
END
GO

-- =======================================================================
-- END ~ Multiple tests. One with TRANSACTION with ROLLBACK and TST rollback disabled ~
-- =======================================================================

-- =======================================================================
-- START ~ TRANSACTION with COMMIT case ~
-- This is the case where the tested stored procedures uses a TRANSACTION and 
-- does a COMMIT.
-- =======================================================================

CREATE PROCEDURE dbo.InsertTestEntryAndCommit
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   BEGIN TRANSACTION
   INSERT INTO dbo.TestTable(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
   COMMIT TRANSACTION
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Proc_Test_TranCommit
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Proc_Test_TranCommit'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Proc_Test_TranCommit
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Proc_Test_TranCommit'

   DELETE dbo.TestTable WHERE EntryValue = 'SQLTest_Proc_Test_TranCommit#Test'

END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Test_TranCommit#Test
AS
BEGIN

   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC dbo.InsertTestEntryAndCommit 'SQLTest_Proc_Test_TranCommit#Test', @EntryId OUT
   
   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryValue = 'SQLTest_Proc_Test_TranCommit#Test' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_TranCommit#Test', 1, @RowCount
   
END
GO

-- =======================================================================
-- END ~ TRANSACTION with COMMIT case ~
-- =======================================================================

-- =======================================================================
-- START ~ TRANSACTION left open case ~
-- This is the case where the tested stored procedures opens a TRANSACTION 
-- and leaves it open.
-- =======================================================================
CREATE PROCEDURE dbo.InsertTestEntryAndBeginTran1
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   BEGIN TRANSACTION
   INSERT INTO dbo.TestTable(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Proc_Test_TranBegin
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Proc_Test_TranBegin'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Proc_Test_TranBegin
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Proc_Test_TranBegin'

   DELETE dbo.TestTable WHERE EntryValue = 'SQLTest_Proc_Test_TranBegin#Test'
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Test_TranBegin#Test
AS
BEGIN

   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.Equals 'TestAssert in SQLTest_Proc_Test_TranBegin#Test', 1, 1
   EXEC dbo.InsertTestEntryAndBeginTran1 'SQLTest_Proc_Test_TranBegin#Test', @EntryId OUT
   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryValue = 'SQLTest_Proc_Test_TranBegin#Test' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_TranBegin#Test', 1, @RowCount
   
END
GO

-- =======================================================================
-- END ~ TRANSACTION left open case ~
-- =======================================================================

-- =======================================================================
-- START ~ TRANSACTION left open case and TST rollback disabled ~
-- This is the case where the tested stored procedures opens a TRANSACTION 
-- and leaves it open but TST rollback is disabled via TSTConfig.
-- =======================================================================

CREATE PROCEDURE dbo.InsertTestEntryAndBeginTran2
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   BEGIN TRANSACTION
   INSERT INTO dbo.TestTable(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Proc_Test_TranBeginSRDisabled
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Proc_Test_TranBeginSRDisabled'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Proc_Test_TranBeginSRDisabled
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Proc_Test_TranBeginSRDisabled'

   DELETE dbo.TestTable WHERE EntryValue = 'SQLTest_Proc_Test_TranBeginSRDisabled#Test'
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Test_TranBeginSRDisabled#Test
AS
BEGIN

   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.Equals 'TestAssert in SQLTest_Proc_Test_TranBeginSRDisabled#Test', 1, 1
   EXEC dbo.InsertTestEntryAndBeginTran2 'SQLTest_Proc_Test_TranBeginSRDisabled#Test', @EntryId OUT
   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryValue = 'SQLTest_Proc_Test_TranBeginSRDisabled#Test' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Test_TranBeginSRDisabled#Test', 1, @RowCount
   
END
GO

-- =======================================================================
-- END ~ TRANSACTION left open case and TST rollback disabled ~
-- =======================================================================


-- =======================================================================
-- START ~ SETUP/TRANSACTION with ROLLBACK case ~
-- This is the case where the setup stored procedures uses a TRANSACTION 
-- and does a ROLLBACK.
-- =======================================================================

CREATE PROCEDURE dbo.InsertTestEntryAndRollbackS1
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   BEGIN TRANSACTION
   INSERT INTO dbo.TestTable(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
   ROLLBACK TRANSACTION
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Proc_Setup_TranRollback
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Proc_Setup_TranRollback'

   EXEC dbo.InsertTestEntryAndRollbackS1 'SQLTest_SETUP_Proc_Setup_TranRollback', @EntryId OUT

   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryValue = 'SQLTest_SETUP_Proc_Setup_TranRollback' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_SETUP_Proc_Setup_TranRollback', 0, @RowCount

END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Proc_Setup_TranRollback
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Proc_Setup_TranRollback'
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Setup_TranRollback#Test
AS
BEGIN
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Setup_TranRollback#Test', 1, 1
END
GO

-- =======================================================================
-- END ~ SETUP/TRANSACTION with ROLLBACK case ~
-- =======================================================================

-- =======================================================================
-- START ~ SETUP/TRANSACTION with ROLLBACK and TST rollback disabled ~
-- This is the case where the setup stored procedures uses a TRANSACTION 
-- and does a ROLLBACK but TST rollback is disabled via TSTConfig.
-- =======================================================================
CREATE PROCEDURE dbo.InsertTestEntryAndRollbackS2
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   BEGIN TRANSACTION
   INSERT INTO dbo.TestTable(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
   ROLLBACK TRANSACTION
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Proc_Setup_TranRollbackSRDisabled
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Proc_Setup_TranRollbackSRDisabled'

   EXEC dbo.InsertTestEntryAndRollbackS2 'SQLTest_SETUP_Proc_Setup_TranRollbackSRDisabled', @EntryId OUT

   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryValue = 'SQLTest_SETUP_Proc_Setup_TranRollbackSRDisabled' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_SETUP_Proc_Setup_TranRollbackSRDisabled', 0, @RowCount

END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Proc_Setup_TranRollbackSRDisabled
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Proc_Setup_TranRollbackSRDisabled'
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Setup_TranRollbackSRDisabled#Test
AS
BEGIN
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Setup_TranRollbackSRDisabled#Test', 1, 1
END
GO

-- =======================================================================
-- END ~ SETUP/TRANSACTION with ROLLBACK and TST rollback disabled ~
-- =======================================================================

-- =======================================================================
-- START ~ SETUP/TRANSACTION left open case ~
-- This is the case where the setup stored procedures opens a TRANSACTION 
-- and leaves it open.
-- =======================================================================
CREATE PROCEDURE dbo.InsertTestEntryAndBeginTranS1
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   BEGIN TRANSACTION
   INSERT INTO dbo.TestTable(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Proc_Setup_TranBegin
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Proc_Setup_TranBegin'

   EXEC dbo.InsertTestEntryAndBeginTranS1 'SQLTest_SETUP_Proc_Setup_TranBegin', @EntryId OUT
   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryValue = 'SQLTest_SETUP_Proc_Setup_TranBegin' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_SETUP_Proc_Setup_TranBegin', 1, @RowCount
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Proc_Setup_TranBegin
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Proc_Setup_TranBegin'

   DELETE dbo.TestTable WHERE EntryValue = 'SQLTest_SETUP_Proc_Setup_TranBegin'
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Setup_TranBegin#Test
AS
BEGIN
   EXEC TST.Assert.Equals 'TestAssert in SQLTest_Proc_Setup_TranBegin#Test', 1, 1
END
GO

-- =======================================================================
-- END ~ SETUP/TRANSACTION left open case ~
-- =======================================================================

-- =======================================================================
-- START ~ TEARDOWN/TRANSACTION with ROLLBACK case ~
-- This is the case where the teardown stored procedures uses a TRANSACTION 
-- and does a ROLLBACK.
-- =======================================================================

CREATE PROCEDURE dbo.InsertTestEntryAndRollbackT1
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   BEGIN TRANSACTION
   INSERT INTO dbo.TestTable(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
   ROLLBACK TRANSACTION
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Proc_Teardown_TranRollback
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Proc_Teardown_TranRollback'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Proc_Teardown_TranRollback
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Proc_Teardown_TranRollback'

   EXEC dbo.InsertTestEntryAndRollbackT1 'SQLTest_TEARDOWN_Proc_Teardown_TranRollback', @EntryId OUT

   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryValue = 'SQLTest_TEARDOWN_Proc_Teardown_TranRollback' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Proc_Teardown_TranRollback', 0, @RowCount
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Teardown_TranRollback#Test
AS
BEGIN
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Teardown_TranRollback#Test', 1, 1
END
GO

-- =======================================================================
-- END ~ TEARDOWN/TRANSACTION with ROLLBACK case ~
-- =======================================================================

-- =======================================================================
-- START ~ TEARDOWN/TRANSACTION with ROLLBACK and TST rollback disabled ~
-- This is the case where the teardown stored procedures uses a TRANSACTION 
-- and does a ROLLBACK but TST rollback is disabled via TSTConfig.
-- =======================================================================

CREATE PROCEDURE dbo.InsertTestEntryAndRollbackT2
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   BEGIN TRANSACTION
   INSERT INTO dbo.TestTable(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
   ROLLBACK TRANSACTION
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Proc_Teardown_TranRollbackSRDisabled
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Proc_Teardown_TranRollbackSRDisabled'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Proc_Teardown_TranRollbackSRDisabled
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Proc_Teardown_TranRollbackSRDisabled'

   EXEC dbo.InsertTestEntryAndRollbackT2 'SQLTest_TEARDOWN_Proc_Teardown_TranRollbackSRDisabled', @EntryId OUT

   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryValue = 'SQLTest_TEARDOWN_Proc_Teardown_TranRollbackSRDisabled' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Proc_Teardown_TranRollbackSRDisabled', 0, @RowCount
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Teardown_TranRollbackSRDisabled#Test
AS
BEGIN
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Proc_Teardown_TranRollbackSRDisabled#Test', 1, 1
END
GO

-- =======================================================================
-- END ~ TEARDOWN/TRANSACTION with ROLLBACK and TST rollback disabled ~
-- =======================================================================

-- =======================================================================
-- START ~ TEARDOWN/TRANSACTION left open case ~
-- This is the case where the teardown stored procedures opens a TRANSACTION 
-- and leaves it open.
-- =======================================================================
CREATE PROCEDURE dbo.InsertTestEntryAndBeginTranT1
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   BEGIN TRANSACTION
   INSERT INTO dbo.TestTable(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Proc_Teardown_TranBegin
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Proc_Teardown_TranBegin'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Proc_Teardown_TranBegin
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Proc_Teardown_TranBegin'

   EXEC dbo.InsertTestEntryAndBeginTranT1 'SQLTest_TEARDOWN_Proc_Teardown_TranBegin', @EntryId OUT
   
   -- TODO: In "EntryValue = 'SQLTest_TEARDOWN_Proc_Teardown_TranBegin' AND EntryId = @EntryId" we should get rid ofone condition
   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryValue = 'SQLTest_TEARDOWN_Proc_Teardown_TranBegin' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Proc_Teardown_TranBegin', 1, @RowCount

   DELETE dbo.TestTable WHERE EntryValue = 'SQLTest_TEARDOWN_Proc_Teardown_TranBegin'
   SELECT @RowCount = COUNT(*) FROM dbo.TestTable WHERE EntryValue = 'SQLTest_TEARDOWN_Proc_Teardown_TranBegin' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Proc_Teardown_TranBegin', 0, @RowCount
END
GO

CREATE PROCEDURE dbo.SQLTest_Proc_Teardown_TranBegin#Test
AS
BEGIN
   EXEC TST.Assert.Equals 'TestAssert in SQLTest_Proc_Teardown_TranBegin#Test', 1, 1
END
GO

-- =======================================================================
-- END ~ TEARDOWN/TRANSACTION left open case ~
-- =======================================================================

-- =======================================================================
-- START ~ TRIGGER / No Transactions case ~
-- This is the regular case where the trigger involved does not use 
-- transactions.
-- =======================================================================

CREATE TRIGGER TR_TestTableTRG1_NoTransactions ON dbo.TestTableTRG1 AFTER INSERT, UPDATE, DELETE 
AS
   DECLARE @ValueBefore       varchar(1000)
   DECLARE @ValueAfter        varchar(1000)
   DECLARE @TriggerMessage    varchar(1000)
   
   SELECT @ValueBefore = Deleted.EntryValue FROM Deleted
   SELECT @ValueAfter  = Inserted.EntryValue FROM Inserted
   
   SET @TriggerMessage = 'TestTableTRG1. Value before: ' + ISNULL(@ValueBefore, 'null') + '. Value after: ' + ISNULL(@ValueAfter, 'null')
   INSERT INTO TriggerLog(LogMessage) VALUES (@TriggerMessage)
GO

CREATE PROCEDURE dbo.InsertTestEntryTriggerNoTransaction
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   INSERT INTO dbo.TestTableTRG1(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Trigger_NoTransactions
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Trigger_NoTransactions'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Trigger_NoTransactions
AS
BEGIN
   EXEC TST.Assert.Equals  'TestAssert in SQLTest_TEARDOWN_Trigger_NoTransactions', 1, 1
   
   DELETE dbo.TestTableTRG1 WHERE EntryValue = 'SQLTest_Trigger_NoTransactions#Test'
   DELETE dbo.TriggerLog    WHERE LogMessage = 'SQLTest_Trigger_NoTransactions#Test'
END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_NoTransactions#Test
AS
BEGIN

   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.Equals 'TestAssert in SQLTest_Trigger_NoTransactions#Test', 1, 1
   EXEC dbo.InsertTestEntryTriggerNoTransaction 'SQLTest_Trigger_NoTransactions#Test', @EntryId OUT
   
   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG1 WHERE EntryValue = 'SQLTest_Trigger_NoTransactions#Test' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_NoTransactions#Test. Row count in TestTableTRG1.', 1, @RowCount
   
   SELECT @RowCount = COUNT(*) FROM dbo.TriggerLog WHERE LogMessage LIKE '%SQLTest_Trigger_NoTransactions#Test%'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_NoTransactions#Test. Row count in TriggerLog', 1, @RowCount

END
GO

-- =======================================================================
-- END ~ TRIGGER / No Transactions case ~
-- =======================================================================

CREATE TRIGGER TR_TestTableTRG2_TransactionsRollback ON dbo.TestTableTRG2 AFTER INSERT
AS
   DECLARE @ValueBefore       varchar(1000)
   DECLARE @ValueAfter        varchar(1000)
   DECLARE @TriggerMessage    varchar(1000)
   
   SELECT @ValueBefore = Deleted.EntryValue FROM Deleted
   SELECT @ValueAfter  = Inserted.EntryValue FROM Inserted
   
   SET @TriggerMessage = 'TestTableTRG2. Value before: ' + ISNULL(@ValueBefore, 'null') + '. Value after: ' + ISNULL(@ValueAfter, 'null')

   BEGIN TRANSACTION
   INSERT INTO TriggerLog(LogMessage) VALUES (@TriggerMessage)
   ROLLBACK TRANSACTION
GO

CREATE PROCEDURE dbo.InsertTestEntryTriggerTransactionRollback
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   INSERT INTO dbo.TestTableTRG2(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
END
GO

-- =======================================================================
-- START ~ TRIGGER/ROLLBACK Transactions case ~
-- This is the case where the tested stored procedures involves a trigger 
-- that uses a TRANSACTION and does a ROLLBACK.
-- =======================================================================

CREATE PROCEDURE dbo.SQLTest_SETUP_Trigger_Test_TranRollback
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Trigger_Test_TranRollback'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Trigger_Test_TranRollback
AS
BEGIN

   DECLARE @RowCount int

   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Trigger_Test_TranRollback'
   
   DELETE dbo.TestTableTRG2 WHERE EntryValue = 'SQLTest_Trigger_Test_TranRollback#Test'
   DELETE dbo.TriggerLog    WHERE LogMessage = 'SQLTest_Trigger_Test_TranRollback#Test'

   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG2 WHERE EntryValue = 'SQLTest_Trigger_Test_TranRollback#Test'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Trigger_Test_TranRollback. Row count in TestTableTRG2', 0, @RowCount
   
   SELECT @RowCount = COUNT(*) FROM dbo.TriggerLog WHERE LogMessage LIKE '%SQLTest_Trigger_Test_TranRollback#Test%'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Trigger_Test_TranRollback. Row count in TriggerLog', 0, @RowCount

END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Test_TranRollback#Test
AS
BEGIN

   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is in SQLTest_Trigger_Test_TranRollback#Test'
   EXEC dbo.InsertTestEntryTriggerTransactionRollback 'SQLTest_Trigger_Test_TranRollback#Test', @EntryId OUT
   
   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG2 WHERE EntryValue = 'SQLTest_Trigger_Test_TranRollback#Test' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_TranRollback#Test. Row count in TestTableTRG2', 1, @RowCount
   
   SELECT @RowCount = COUNT(*) FROM dbo.TriggerLog WHERE LogMessage LIKE '%SQLTest_Trigger_Test_TranRollback#Test%'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_TranRollback#Test. Row count in TriggerLog', 1, @RowCount

END
GO

-- =======================================================================
-- END ~ TRIGGER/ROLLBACK Transactions case ~
-- =======================================================================

-- =======================================================================
-- START ~ TRIGGER/ROLLBACK Transactions case ~
-- This is the case where the tested stored procedures involves a trigger
-- that uses a TRANSACTION and does a ROLLBACK but TST rollback is 
-- disabled via TSTConfig.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SETUP_Trigger_Test_TranRollbackSRDisabled
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Trigger_Test_TranRollbackSRDisabled'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Trigger_Test_TranRollbackSRDisabled
AS
BEGIN

   DECLARE @RowCount int

   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Trigger_Test_TranRollbackSRDisabled'
   
   DELETE dbo.TestTableTRG2 WHERE EntryValue = 'SQLTest_Trigger_Test_TranRollbackSRDisabled#Test'
   DELETE dbo.TriggerLog    WHERE LogMessage = 'SQLTest_Trigger_Test_TranRollbackSRDisabled#Test'

   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG2 WHERE EntryValue = 'SQLTest_Trigger_Test_TranRollbackSRDisabled#Test'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Trigger_Test_TranRollbackSRDisabled. Row count in TestTableTRG2', 0, @RowCount
   
   SELECT @RowCount = COUNT(*) FROM dbo.TriggerLog WHERE LogMessage LIKE '%SQLTest_Trigger_Test_TranRollbackSRDisabled#Test%'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Trigger_Test_TranRollbackSRDisabled. Row count in TriggerLog', 0, @RowCount

END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Test_TranRollbackSRDisabled#Test
AS
BEGIN

   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is in SQLTest_Trigger_Test_TranRollbackSRDisabled#Test'
   EXEC dbo.InsertTestEntryTriggerTransactionRollback 'SQLTest_Trigger_Test_TranRollbackSRDisabled#Test', @EntryId OUT
   
   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG2 WHERE EntryValue = 'SQLTest_Trigger_Test_TranRollbackSRDisabled#Test' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_TranRollbackSRDisabled#Test. Row count in TestTableTRG2', 1, @RowCount
   
   SELECT @RowCount = COUNT(*) FROM dbo.TriggerLog WHERE LogMessage LIKE '%SQLTest_Trigger_Test_TranRollbackSRDisabled#Test%'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_TranRollbackSRDisabled#Test. Row count in TriggerLog', 1, @RowCount

END
GO

-- =======================================================================
-- END ~ TRIGGER/ROLLBACK Transactions and TST rollback disabled ~
-- =======================================================================

-- =======================================================================
-- START ~ TRIGGER/ROLLBACK - Multiple tests. 
-- This is the case where one of the tested stored procedures involves 
-- a trigger that uses a TRANSACTION and does a ROLLBACK.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SETUP_Trigger_Test_Multi_TranRollback
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Trigger_Test_Multi_TranRollback'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollback
AS
BEGIN
   DECLARE @RowCount int

   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollback'
   
   DELETE dbo.TestTableTRG2 WHERE EntryValue = 'SQLTest_Trigger_Test_Multi_TranRollback#Test'
   DELETE dbo.TriggerLog    WHERE LogMessage = 'SQLTest_Trigger_Test_Multi_TranRollback#Test'

   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG2 WHERE EntryValue = 'SQLTest_Trigger_Test_Multi_TranRollback#Test'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollback. Row count in TestTableTRG2', 0, @RowCount
   
   SELECT @RowCount = COUNT(*) FROM dbo.TriggerLog WHERE LogMessage LIKE '%SQLTest_Trigger_Test_Multi_TranRollback#Test%'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollback. Row count in TriggerLog', 0, @RowCount

END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Test_Multi_TranRollback#TestB
AS
BEGIN

   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is in SQLTest_Trigger_Test_Multi_TranRollback#TestB'
   EXEC dbo.InsertTestEntryTriggerTransactionRollback 'SQLTest_Trigger_Test_Multi_TranRollback#TestB', @EntryId OUT
   
   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG2 WHERE EntryValue = 'SQLTest_Trigger_Test_Multi_TranRollback#TestB' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_Multi_TranRollback#TestB. Row count in TestTableTRG2', 1, @RowCount
   
   SELECT @RowCount = COUNT(*) FROM dbo.TriggerLog WHERE LogMessage LIKE '%SQLTest_Trigger_Test_Multi_TranRollback#TestB%'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_Multi_TranRollback#TestB. Row count in TriggerLog', 1, @RowCount

END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Test_Multi_TranRollback#TestA
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_Multi_TranRollback#TestA', 1, 1
END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Test_Multi_TranRollback#TestC
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_Multi_TranRollback#TestC', 1, 1
END
GO

-- =======================================================================
-- END ~ TRIGGER/ROLLBACK - Multiple tests. 
-- =======================================================================

-- =======================================================================
-- START ~ TRIGGER/ROLLBACK - Multiple tests and TST rollback disabled ~
-- This is the case where one of the tested stored procedures involves 
-- a trigger that uses a TRANSACTION and does a ROLLBACK but 
-- TST rollback is disabled via TSTConfig.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SETUP_Trigger_Test_Multi_TranRollbackSRDisabled
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Trigger_Test_Multi_TranRollbackSRDisabled'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollbackSRDisabled
AS
BEGIN
   DECLARE @RowCount int

   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollbackSRDisabled'
   
   DELETE dbo.TestTableTRG2 WHERE EntryValue = 'SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB'
   DELETE dbo.TriggerLog    WHERE LogMessage = 'SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB'

   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG2 WHERE EntryValue = 'SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#Test'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollbackSRDisabled. Row count in TestTableTRG2', 0, @RowCount
   
   SELECT @RowCount = COUNT(*) FROM dbo.TriggerLog WHERE LogMessage LIKE '%SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#Test%'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollbackSRDisabled. Row count in TriggerLog', 0, @RowCount

END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB
AS
BEGIN

   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is in SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB'
   EXEC dbo.InsertTestEntryTriggerTransactionRollback 'SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB', @EntryId OUT
   
   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG2 WHERE EntryValue = 'SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB. Row count in TestTableTRG2', 1, @RowCount
   
   SELECT @RowCount = COUNT(*) FROM dbo.TriggerLog WHERE LogMessage LIKE '%SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB%'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB. Row count in TriggerLog', 1, @RowCount

END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestA
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestA', 1, 1
END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestC
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestC', 1, 1
END
GO

-- =======================================================================
-- END ~ TRIGGER/ROLLBACK - Multiple tests. 
-- =======================================================================

-- =======================================================================
-- START ~ TRIGGER/COMMIT case ~
-- This is the case where the tested stored procedures involves a trigger 
-- that uses a TRANSACTION and does a COMMIT.
-- =======================================================================
CREATE TRIGGER TR_TestTableTRG3_TransactionsCommit ON dbo.TestTableTRG3 AFTER INSERT
AS
   DECLARE @ValueBefore       varchar(1000)
   DECLARE @ValueAfter        varchar(1000)
   DECLARE @TriggerMessage    varchar(1000)
   
   SELECT @ValueBefore = Deleted.EntryValue FROM Deleted
   SELECT @ValueAfter  = Inserted.EntryValue FROM Inserted
   
   SET @TriggerMessage = 'TestTableTRG3. Value before: ' + ISNULL(@ValueBefore, 'null') + '. Value after: ' + ISNULL(@ValueAfter, 'null')

   BEGIN TRANSACTION
   INSERT INTO TriggerLog(LogMessage) VALUES (@TriggerMessage)
   COMMIT TRANSACTION
GO

CREATE PROCEDURE dbo.InsertTestEntryTriggerTransactionCommit 
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   INSERT INTO dbo.TestTableTRG3(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
END
GO

CREATE PROCEDURE dbo.SQLTest_SETUP_Trigger_Test_TranCommit
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Trigger_Test_TranCommit'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Trigger_Test_TranCommit
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Trigger_Test_TranCommit'

   DELETE dbo.TestTable WHERE EntryValue = 'SQLTest_Trigger_Test_TranCommit#Test'

END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Test_TranCommit#Test
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is SQLTest_Trigger_Test_TranCommit#Test'
   EXEC dbo.InsertTestEntryTriggerTransactionCommit 'SQLTest_Trigger_Test_TranCommit#Test', @EntryId OUT
   
   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG3 WHERE EntryValue = 'SQLTest_Trigger_Test_TranCommit#Test' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_TranCommit#Test', 1, @RowCount
END
GO

-- =======================================================================
-- END ~ TRIGGER/COMMIT case ~
-- =======================================================================

CREATE TRIGGER TR_TestTableTRG4_TransactionsBegin ON dbo.TestTableTRG4 AFTER INSERT
AS
   DECLARE @ValueBefore       varchar(1000)
   DECLARE @ValueAfter        varchar(1000)
   DECLARE @TriggerMessage    varchar(1000)
   
   SELECT @ValueBefore = Deleted.EntryValue FROM Deleted
   SELECT @ValueAfter  = Inserted.EntryValue FROM Inserted
   
   SET @TriggerMessage = 'TestTableTRG4. Value before: ' + ISNULL(@ValueBefore, 'null') + '. Value after: ' + ISNULL(@ValueAfter, 'null')

   BEGIN TRANSACTION
   INSERT INTO TriggerLog(LogMessage) VALUES (@TriggerMessage)
GO

CREATE PROCEDURE dbo.InsertTestEntryTriggerTransactionBegin
   @TestValue     varchar(1000),
   @EntryId       int OUT
AS
BEGIN
   INSERT INTO dbo.TestTableTRG4(EntryValue) VALUES (@TestValue)
   SET @EntryId = SCOPE_IDENTITY()
END
GO

-- =======================================================================
-- START ~ TRIGGER/TRANSACTION left open case ~
-- This is the case where the tested stored procedures involves a trigger 
-- that opens a TRANSACTION and leaves it open.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SETUP_Trigger_Test_TranBegin
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Trigger_Test_TranBegin'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Trigger_Test_TranBegin
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Trigger_Test_TranBegin'

   DELETE dbo.TestTable WHERE EntryValue = 'SQLTest_Trigger_Test_TranBegin#Test'

END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Test_TranBegin#Test
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is SQLTest_Trigger_Test_TranBegin#Test'
   EXEC dbo.InsertTestEntryTriggerTransactionBegin 'SQLTest_Trigger_Test_TranBegin#Test', @EntryId OUT
   
   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG3 WHERE EntryValue = 'SQLTest_Trigger_Test_TranBegin#Test' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_TranBegin#Test', 1, @RowCount
END
GO


-- =======================================================================
-- START ~ TRIGGER/TRANSACTION left open case ~
-- This is the case where the tested stored procedures involves a trigger 
-- that opens a TRANSACTION and leaves it open but TST rollback is 
-- disabled via TSTConfig.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SETUP_Trigger_Test_TranBeginSRDisabled
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Trigger_Test_TranBeginSRDisabled'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Trigger_Test_TranBeginSRDisabled
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Trigger_Test_TranBeginSRDisabled'

   DELETE dbo.TestTable WHERE EntryValue = 'SQLTest_Trigger_Test_TranBeginSRDisabled#Test'

END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Test_TranBeginSRDisabled#Test
AS
BEGIN
   DECLARE @RowCount int
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is SQLTest_Trigger_Test_TranBeginSRDisabled#Test'
   EXEC dbo.InsertTestEntryTriggerTransactionBegin 'SQLTest_Trigger_Test_TranBeginSRDisabled#Test', @EntryId OUT
   
   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG3 WHERE EntryValue = 'SQLTest_Trigger_Test_TranBeginSRDisabled#Test' AND EntryId = @EntryId
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_Trigger_Test_TranBeginSRDisabled#Test', 1, @RowCount
END
GO

-- =======================================================================
-- END ~ TRIGGER/TRANSACTION left open case ~
-- =======================================================================


-- =======================================================================
-- START ~ TRIGGER SETUP/ROLLBACK - Multiple tests. 
-- This is the case where the stup stored procedures involves 
-- a trigger that uses a TRANSACTION and does a ROLLBACK.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SETUP_Trigger_Setup_Multi_TranRollback
AS
BEGIN

   DECLARE @EntryId int
   
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Trigger_Setup_Multi_TranRollback'

   EXEC dbo.InsertTestEntryTriggerTransactionRollback 'SQLTest_SETUP_Trigger_Setup_Multi_TranRollback', @EntryId OUT

   EXEC TST.Assert.LogInfo  'This log should not be executed'

END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollback
AS
BEGIN
   DECLARE @RowCount int

   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollback'
   
   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG2 WHERE EntryValue = 'SQLTest_SETUP_Trigger_Setup_Multi_TranRollback'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollback. Row count in TestTableTRG2', 0, @RowCount
   
   SELECT @RowCount = COUNT(*) FROM dbo.TriggerLog WHERE LogMessage LIKE '%SQLTest_SETUP_Trigger_Setup_Multi_TranRollback%'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollback. Row count in TriggerLog', 0, @RowCount

END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Setup_Multi_TranRollback#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo  'This log should not be executed'
END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Setup_Multi_TranRollback#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo  'This log should not be executed'
END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Setup_Multi_TranRollback#TestC
AS
BEGIN
   EXEC TST.Assert.LogInfo  'This log should not be executed'
END
GO

-- =======================================================================
-- END ~ TRIGGER SETUP/ROLLBACK - Multiple tests. 
-- =======================================================================


-- =======================================================================
-- START ~ TRIGGER SETUP/ROLLBACK - Multiple tests. 
-- This is the case where the stup stored procedures involves 
-- a trigger that uses a TRANSACTION and does a ROLLBACK.
-- TST rollback is disabled via TSTConfig.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SETUP_Trigger_Setup_Multi_TranRollbackSRDisabled
AS
BEGIN

   DECLARE @EntryId int
   
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Trigger_Setup_Multi_TranRollbackSRDisabled'

   EXEC dbo.InsertTestEntryTriggerTransactionRollback 'SQLTest_SETUP_Trigger_Setup_Multi_TranRollbackSRDisabled', @EntryId OUT

   EXEC TST.Assert.LogInfo  'This log should not be executed'

END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollbackSRDisabled
AS
BEGIN
   DECLARE @RowCount int

   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollbackSRDisabled'
   
   SELECT @RowCount = COUNT(*) FROM dbo.TestTableTRG2 WHERE EntryValue = 'SQLTest_SETUP_Trigger_Setup_Multi_TranRollbackSRDisabled'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollbackSRDisabled. Row count in TestTableTRG2', 0, @RowCount
   
   SELECT @RowCount = COUNT(*) FROM dbo.TriggerLog WHERE LogMessage LIKE '%SQLTest_SETUP_Trigger_Setup_Multi_TranRollbackSRDisabled%'
   EXEC TST.Assert.Equals 'Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollbackSRDisabled. Row count in TriggerLog', 0, @RowCount

END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo  'This log should not be executed'
END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo  'This log should not be executed'
END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestC
AS
BEGIN
   EXEC TST.Assert.LogInfo  'This log should not be executed'
END
GO

-- =======================================================================
-- END ~ TRIGGER SETUP/ROLLBACK - Multiple tests. 
-- =======================================================================


-- =======================================================================
-- START ~ TRIGGER TEARDOWN/ROLLBACK - Multiple tests. 
-- This is the case where the teardown stored procedures involves 
-- a trigger that uses a TRANSACTION and does a ROLLBACK.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SETUP_Trigger_Teardown_Multi_TranRollback
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This log will be lost'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Trigger_Teardown_Multi_TranRollback
AS
BEGIN
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Trigger_Teardown_Multi_TranRollback'
   
   EXEC dbo.InsertTestEntryTriggerTransactionRollback 'SQLTest_SETUP_Trigger_Setup_Multi_TranRollbackSRDisabled', @EntryId OUT

   EXEC TST.Assert.LogInfo  'This log should not be executed'
END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Teardown_Multi_TranRollback#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This log will be lost'
END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Teardown_Multi_TranRollback#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This log will be lost'
END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Teardown_Multi_TranRollback#TestC
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This log will be lost'
END
GO

-- =======================================================================
-- END ~ TRIGGER SETUP/ROLLBACK - Multiple tests. 
-- =======================================================================

-- =======================================================================
-- START ~ TRIGGER TEARDOWN/ROLLBACK - Multiple tests. 
-- This is the case where the teardown stored procedures involves 
-- a trigger that uses a TRANSACTION and does a ROLLBACK.
-- TST rollback is disabled via TSTConfig.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SETUP_Trigger_Teardown_Multi_TranRollbackSRDisabled
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Trigger_Teardown_Multi_TranRollbackSRDisabled'
END
GO

CREATE PROCEDURE dbo.SQLTest_TEARDOWN_Trigger_Teardown_Multi_TranRollbackSRDisabled
AS
BEGIN
   DECLARE @EntryId int

   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Trigger_Teardown_Multi_TranRollbackSRDisabled'
   
   EXEC dbo.InsertTestEntryTriggerTransactionRollback 'SQLTest_SETUP_Trigger_Setup_Multi_TranRollbackSRDisabled', @EntryId OUT

   EXEC TST.Assert.LogInfo  'This log should not be executed'
END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestB'
END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestA'
END
GO

CREATE PROCEDURE dbo.SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestC
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestC'
END
GO

-- =======================================================================
-- END ~ TRIGGER SETUP/ROLLBACK - Multiple tests. 
-- =======================================================================

USE tempdb
GO

