--===================================================================
-- FILE: SetTSTCheckView_TSTResultsEx.sql
-- This script will setup a TST test database.
-- This database will be used to automate part of the self check 
-- scripts - the part that validates the view Data.TSTResultsEx
-- ==================================================================

USE tempdb
GO

-- ==================================================================
-- Creates the TSTCheckView_TSTResultsEx database. 
-- If already exists then drops it first.
-- ==================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckView_TSTResultsEx')
BEGIN
   DROP DATABASE TSTCheckView_TSTResultsEx
END

CREATE DATABASE TSTCheckView_TSTResultsEx
GO

USE TSTCheckView_TSTResultsEx
GO


CREATE PROCEDURE SQLTest_TestOnePassEntry
AS
BEGIN

   EXEC TST.Assert.Equals 'Test passing Assert.Equals in SQLTest_TestOnePassEntry', 1, 1

END
GO

CREATE PROCEDURE SQLTest_TestOneLogEntry
AS
BEGIN

   EXEC TST.Assert.LogInfo 'TST.Assert.LogInfo in SQLTest_TestOneLogEntry'

END
GO

CREATE PROCEDURE SQLTest_TestOneFailEntry
AS
BEGIN

   EXEC TST.Assert.Equals 'Test failing Assert.Equals in SQLTest_TestOneFailEntry', 1, 2

END
GO


CREATE PROCEDURE SQLTest_TestOneErrorEntry
AS
BEGIN

   DECLARE @testInt int
   SET @testInt = CAST ('invalid' as int)

   EXEC TST.Assert.LogInfo 'This log will not be executed'

END
GO

CREATE PROCEDURE SQLTest_SuitePass#TestPass1
AS
BEGIN
   EXEC TST.Assert.Equals 'Test passing Assert.Equals in SQLTest_SuitePass#TestPass1', 1, 1
END
GO

CREATE PROCEDURE SQLTest_SuitePass#TestPass2
AS
BEGIN
   EXEC TST.Assert.Equals 'Test passing Assert.Equals in SQLTest_SuitePass#TestPass2', 1, 1
END
GO

CREATE PROCEDURE SQLTest_SuiteOneFailure#Test_A_Pass
AS
BEGIN
   EXEC TST.Assert.Equals 'Test passing Assert.Equals in SQLTest_SuiteOneFailure#Test_A_Pass', 1, 1
   EXEC TST.Assert.Equals 'Test passing Assert.Equals in SQLTest_SuiteOneFailure#Test_A_Pass', 2, 2
END
GO

CREATE PROCEDURE SQLTest_SuiteOneFailure#Test_B_Fail
AS
BEGIN
   EXEC TST.Assert.Equals 'Test passing Assert.Equals in SQLTest_SuiteOneFailure#Test_B_Fail', 1, 1
   EXEC TST.Assert.Equals 'Test failing Assert.Equals in SQLTest_SuiteOneFailure#Test_B_Fail', 1, 2
END
GO


CREATE PROCEDURE SQLTest_SuiteOneError#Test_A_Pass
AS
BEGIN
   EXEC TST.Assert.Equals 'Test passing Assert.Equals in SQLTest_SuiteOneError#Test_A_Pass', 1, 1
   EXEC TST.Assert.Equals 'Test passing Assert.Equals in SQLTest_SuiteOneError#Test_A_Pass', 2, 2
END
GO

CREATE PROCEDURE SQLTest_SuiteOneError#Test_B_Error
AS
BEGIN
   DECLARE @testInt int

   EXEC TST.Assert.Equals 'Test passing Assert.Equals in SQLTest_SuiteOneError#Test_B_Error', 1, 1

   SET @testInt = CAST ('invalid' as int)

   EXEC TST.Assert.LogInfo 'This log will not be executed'
END
GO

CREATE PROCEDURE SQLTest_SuiteOneFailureOneError#Test_A_Pass
AS
BEGIN
   EXEC TST.Assert.Equals 'Test passing Assert.Equals in SQLTest_SuiteOneFailureOneError#Test_A_Pass', 1, 1
   EXEC TST.Assert.Equals 'Test passing Assert.Equals in SQLTest_SuiteOneFailureOneError#Test_A_Pass', 2, 2
END
GO

CREATE PROCEDURE SQLTest_SuiteOneFailureOneError#Test_B_Fail
AS
BEGIN
   EXEC TST.Assert.Equals 'Test passing Assert.Equals in SQLTest_SuiteOneFailureOneError#Test_B_Fail', 1, 1
   EXEC TST.Assert.Equals 'Test failing Assert.Equals in SQLTest_SuiteOneFailureOneError#Test_B_Fail', 1, 2
END
GO

CREATE PROCEDURE SQLTest_SuiteOneFailureOneError#Test_C_Error
AS
BEGIN
   DECLARE @testInt int

   EXEC TST.Assert.Equals 'Test passing Assert.Equals in SQLTest_SuiteOneFailureOneError#Test_C_Error', 1, 1

   SET @testInt = CAST ('invalid' as int)

   EXEC TST.Assert.LogInfo 'This log will not be executed'
END
GO


USE tempdb
GO
