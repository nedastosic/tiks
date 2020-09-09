--===================================================================
-- FILE: SetTSTCheckTestSession2.sql
-- This script will setup a simple TST test database.
-- This database will be used to automate part of the self check 
-- scripts.
-- ==================================================================

USE tempdb
GO

-- ==================================================================
-- Creates the TSTCheckTestSession_Bx databases. 
-- If they already exist then drops them first.
-- ==================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckTestSession2')
BEGIN
   DROP DATABASE TSTCheckTestSession2
END

CREATE DATABASE TSTCheckTestSession2
GO

USE TSTCheckTestSession2
GO

CREATE SCHEMA TestSchema1
GO

-- ==================================================================
-- The session setup.
-- ==================================================================

CREATE PROCEDURE ValidateTestSessionId @TestSessionId int
AS
BEGIN   
   DECLARE @SessionSetupCount       int
   DECLARE @SuiteSetupCount         int
   DECLARE @SuiteTeardownCount      int
   DECLARE @SessionTeardownCount    int
   DECLARE @TestCount               int
   DECLARE @TestCountSpecificSproc  int

   SELECT @SessionSetupCount = COUNT(*) FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND SProcType = 'SetupS'
   EXEC TST.Assert.Equals 'Check the count of session setup procedures', @SessionSetupCount, 1
   SELECT @SuiteSetupCount = COUNT(*) FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND SProcType = 'Setup'
   EXEC TST.Assert.Equals 'Check the count of suite setup procedures', @SuiteSetupCount, 2
   SELECT @SuiteTeardownCount = COUNT(*) FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND SProcType = 'Teardown'
   EXEC TST.Assert.Equals 'Check the count of suite teardown procedures', @SuiteTeardownCount, 2
   SELECT @SessionTeardownCount = COUNT(*) FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND SProcType = 'TeardownS'
   EXEC TST.Assert.Equals 'Check the count of session teardown procedures', @SessionTeardownCount, 1
   SELECT @TestCount = COUNT(*) FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND SProcType = 'Test'
   EXEC TST.Assert.Equals 'Check the count of test procedures', @TestCount, 6
   SELECT @TestCountSpecificSproc = COUNT(*) FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND SProcType = 'Test' AND SProcName = 'SQLTest_TestDistinctName'
   EXEC TST.Assert.Equals 'Check the presence of one specific test', @TestCountSpecificSproc, 1
END
GO

CREATE PROCEDURE TestSchema1.SQLTest_SESSION_SETUP @TestSessionId int
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_SETUP'
   EXEC ValidateTestSessionId @TestSessionId
END
GO

CREATE PROCEDURE TestSchema1.SQLTest_SESSION_TEARDOWN @TestSessionId int
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_TEARDOWN'
   EXEC ValidateTestSessionId @TestSessionId
END
GO

-- ==================================================================
-- Suite1
-- ==================================================================
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
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Suite1#TestA', 1, 1
END
GO

CREATE PROCEDURE SQLTest_Suite1#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite1#TestB'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Suite1#TestB', 1, 1
END
GO

-- ==================================================================
-- Suite2
-- ==================================================================
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
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Suite2#TestA', 1, 1
END
GO

CREATE PROCEDURE SQLTest_Suite2#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite2#TestB'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Suite2#TestB', 1, 1
END
GO

-- ==================================================================
-- Anonymous Suite
-- ==================================================================
CREATE PROCEDURE SQLTest_Test1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Test1'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Test1', 1, 1
END
GO

CREATE PROCEDURE SQLTest_TestDistinctName
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TestDistinctName'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_TestDistinctName', 1, 1
END
GO

USE tempdb
GO
