--===================================================================
-- FILE: SetTSTCheckSimple.sql
-- This script will setup a simple TST test database.
-- This database will be used to automate part of the self check 
-- scripts.
-- ==================================================================

USE tempdb
GO

-- ==================================================================
-- Creates the TSTCheckSimple database. 
-- If already exists then drops it first.
-- ==================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckSimple')
BEGIN
   DROP DATABASE TSTCheckSimple
END

CREATE DATABASE TSTCheckSimple
GO

USE TSTCheckSimple
GO

CREATE PROCEDURE SQLTest_SETUP_AASuite1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_AASuite1'
END
GO

CREATE PROCEDURE SQLTest_TEARDOWN_AASuite1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_AASuite1'
END
GO

CREATE PROCEDURE SQLTest_AASuite1#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_AASuite1#TestA'
   EXEC TST.Assert.Equals 'Test passing Assert.Equals', 1, 1
END
GO

CREATE PROCEDURE SQLTest_AASuite1#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_AASuite1#TestB'
   EXEC TST.Assert.Equals 'Test passing Assert.Equals', 1, 1
END
GO

CREATE PROCEDURE SQLTest_SETUP_Suite2
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Suite2'
END
GO

CREATE PROCEDURE SQLTest_TEARDOWN_Suite2
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Suite2'
END
GO

CREATE PROCEDURE SQLTest_Suite2#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite2#TestA'
   EXEC TST.Assert.Equals 'Test passing Assert.Equals', 1, 1
END
GO

CREATE PROCEDURE SQLTest_Suite2#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite2#TestB'
   EXEC TST.Assert.Equals 'Test failing Assert.Equals', 1, 2
END
GO

CREATE PROCEDURE SQLTest_SETUP_Suite3
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Suite3'
END
GO

CREATE PROCEDURE SQLTest_TEARDOWN_Suite3
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Suite3'
END
GO

CREATE PROCEDURE SQLTest_Suite3#TestA
AS
BEGIN
   DECLARE @TempVar int

   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite3#TestA'
   SET @TempVar = ISNULL(@TempVar, 'null');  -- This will generate a run-time error

END
GO

CREATE PROCEDURE SQLTest_Suite3#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite3#TestB'
   EXEC TST.Assert.Equals 'Test passing Assert.Equals', 1, 1
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

CREATE PROCEDURE SQLTest_Test3
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Test3'
   EXEC TST.Assert.Equals 'Test failing Assert.Equals', 1, 2
END
GO

CREATE PROCEDURE SQLTest_TestIgnore1
AS
BEGIN
   DECLARE @TempVar int

   EXEC TST.Assert.LogInfo 'This is SQLTest_Test1'
   EXEC TST.Assert.Ignore 'Ignore SQLTest_Test1'

   EXEC TST.Assert.LogInfo 'This line should not be executed'

END
GO

CREATE PROCEDURE SQLTest_TestIgnore2
AS
BEGIN
   DECLARE @TempVar int

   EXEC TST.Assert.LogInfo 'This is SQLTest_Test2'
   EXEC TST.Assert.Equals 'Test passing Assert.Equals', 1, 1
   EXEC TST.Assert.Ignore 'Ignore SQLTest_Test2'

   EXEC TST.Assert.LogInfo 'This line should not be executed'

END
GO

CREATE PROCEDURE SQLTest_TestIgnoreAfterFail
AS
BEGIN
   DECLARE @TempVar int

   EXEC TST.Assert.LogInfo 'This is SQLTest_Test3'
   EXEC TST.Assert.Equals 'Test failing Assert.Equals', 1, 2
   EXEC TST.Assert.LogInfo 'This line should not be executed'
   EXEC TST.Assert.Ignore 'Ignore SQLTest_Test2'

END
GO

CREATE PROCEDURE SQLTest_SETUP_Ignore
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Ignore'
   EXEC TST.Assert.Ignore 'Ignore suite SQLTest_SETUP_Ignore'
END
GO

CREATE PROCEDURE SQLTest_Ignore#TestA
AS
BEGIN
   EXEC TST.Assert.Equals 'Test failing Assert.Equals. This line should not be executed.', 1, 2
END
GO

CREATE PROCEDURE SQLTest_Ignore#TestB
AS
BEGIN
   EXEC TST.Assert.Equals 'Test failing Assert.Equals. This line should not be executed.', 1, 2
END
GO

USE tempdb
GO
