--===================================================================
-- FILE: SetTSTCheckSessionLevelOutput.sql
-- This script will setup a simple TST test database.
-- This database will be used to automate part of the self check 
-- scripts.
-- ==================================================================

USE tempdb
GO

-- ==================================================================
-- Creates the TSTCheckSessionLevelOutput database. 
-- If already exists then drops it first.
-- ==================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckSessionLevelOutput')
BEGIN
   DROP DATABASE TSTCheckSessionLevelOutput
END

CREATE DATABASE TSTCheckSessionLevelOutput
GO

USE TSTCheckSessionLevelOutput
GO

-- =======================================================================
-- TABLE: TestParameters
-- This table contains a flag that signals the session setup/teardown 
-- what they have to execute.
-- =======================================================================
CREATE TABLE dbo.TestParameters
(
   ParameterValue    varchar(100) NOT NULL
)
GO

CREATE PROCEDURE SQLTest_SESSION_SETUP @TestSessionId int
AS
BEGIN

   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_SETUP'
   EXEC TST.Assert.Equals 'Test passing Assert.Equals', 1, 1

   IF EXISTS (SELECT * FROM dbo.TestParameters WHERE ParameterValue = 'Failure in session setup')
   BEGIN
      EXEC TST.Assert.Equals 'Test failing Assert.Equals', 1, 2
   END

   IF EXISTS (SELECT * FROM dbo.TestParameters WHERE ParameterValue = 'Error in session setup')
   BEGIN
      DECLARE @TempVar int
      SET @TempVar = ISNULL(@TempVar, 'null');  -- This will generate a run-time error
   END

   IF EXISTS (SELECT * FROM dbo.TestParameters WHERE ParameterValue = 'Ignore in session setup')
   BEGIN
      EXEC TST.Assert.Ignore 'Ignore in SQLTest_SESSION_SETUP.'
   END

END
GO

CREATE PROCEDURE SQLTest_SESSION_TEARDOWN @TestSessionId int
AS
BEGIN

   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_TEARDOWN'
   EXEC TST.Assert.Equals 'Test passing Assert.Equals', 1, 1

   IF EXISTS (SELECT * FROM dbo.TestParameters WHERE ParameterValue = 'Failure in session teardown')
   BEGIN
      EXEC TST.Assert.Equals 'Test failing Assert.Equals', 1, 2
   END

   IF EXISTS (SELECT * FROM dbo.TestParameters WHERE ParameterValue = 'Error in session teardown')
   BEGIN
      DECLARE @TempVar int
      SET @TempVar = ISNULL(@TempVar, 'null');  -- This will generate a run-time error
   END

   IF EXISTS (SELECT * FROM dbo.TestParameters WHERE ParameterValue = 'Ignore in session teardown')
   BEGIN
      EXEC TST.Assert.Ignore 'Ignore in SQLTest_SESSION_TEARDOWN.'
   END

END
GO

CREATE PROCEDURE SQLTest_SETUP_Suite1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Suite1'
END
GO

CREATE PROCEDURE SQLTest_TEARDOWN_Suite1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Suite1'
END
GO

CREATE PROCEDURE SQLTest_Suite1#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite1#TestA'
   EXEC TST.Assert.Equals 'Test passing Assert.Equals', 1, 1
END
GO

CREATE PROCEDURE SQLTest_Suite1#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite1#TestB'
   EXEC TST.Assert.Equals 'Test failing Assert.Equals', 1, 2
END
GO

CREATE PROCEDURE SQLTest_Test1
AS
BEGIN
   DECLARE @TempVar int

   EXEC TST.Assert.LogInfo 'This is SQLTest_Test1'
   SET @TempVar = ISNULL(@TempVar, 'null');  -- This will generate a run-time error
END
GO

CREATE PROCEDURE SQLTest_Test2
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Test2'
   EXEC TST.Assert.Equals 'Test passing Assert.Equals', 1, 1
END
GO

USE tempdb
GO
