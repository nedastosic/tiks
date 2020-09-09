--===================================================================
-- FILE: SetTSTCheckIgnore.sql
-- This script will setup a simple TST test database.
-- This database will be used to automate part of the self check 
-- scripts.
-- ==================================================================

USE tempdb
GO

-- ==================================================================
-- Creates the TSTCheckIgnore database. 
-- If already exists then drops it first.
-- ==================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckIgnore')
BEGIN
   DROP DATABASE TSTCheckIgnore
END

CREATE DATABASE TSTCheckIgnore
GO

USE TSTCheckIgnore
GO

-- =======================================================================
-- TABLE: TestParameters
-- This table contains a flag that signals the session setup/teardown 
-- if they are supposed to call Assert.Ignore
-- =======================================================================
CREATE TABLE dbo.TestParameters
(
   ParameterValue    char NOT NULL
)
GO

CREATE PROCEDURE SQLTest_SESSION_SETUP @TestSessionId int
AS
BEGIN

   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_SETUP'

   IF EXISTS (SELECT * FROM dbo.TestParameters WHERE ParameterValue = 'S')
   BEGIN
      EXEC TST.Assert.Ignore 'Ignore in SQLTest_SESSION_SETUP.'
   END

END
GO

CREATE PROCEDURE SQLTest_SESSION_TEARDOWN @TestSessionId int
AS
BEGIN

   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_TEARDOWN'

   IF EXISTS (SELECT * FROM dbo.TestParameters WHERE ParameterValue = 'T')
   BEGIN
      EXEC TST.Assert.Ignore 'Ignore in SQLTest_SESSION_TEARDOWN.'
   END

END
GO

CREATE PROCEDURE SQLTest_Test1
AS
BEGIN
   EXEC TST.Assert.Ignore 'Ignore SQLTest_Test1'
   EXEC TST.Assert.Equals 'This line should not be executed', 1, 1
END
GO

CREATE PROCEDURE SQLTest_Test2
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Test2'
   EXEC TST.Assert.Equals 'Passing Assert.Equals in SQLTest_Test2', 1, 1
   EXEC TST.Assert.Ignore 'Ignore SQLTest_Test2'

   EXEC TST.Assert.Equals 'This line should not be executed', 1, 2
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
   EXEC TST.Assert.Ignore 'Ignore SQLTest_Suite1#TestA'
   EXEC TST.Assert.Equals 'This line should not be executed', 1, 1
END
GO

CREATE PROCEDURE SQLTest_Suite1#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite1#TestB'
   EXEC TST.Assert.Equals 'Passing Assert.Equals in SQLTest_Suite1#TestB', 1, 1
   EXEC TST.Assert.Ignore 'Ignore SQLTest_Suite1#TestB'
   EXEC TST.Assert.Equals 'This line should not be executed', 1, 2
END
GO

CREATE PROCEDURE SQLTest_Suite1#TestC
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite1#TestC'
   EXEC TST.Assert.Equals 'Test failing Assert.Equals in SQLTest_Suite1#TestC', 1, 2
   EXEC TST.Assert.Ignore 'This line should not be executed'
END
GO

CREATE PROCEDURE SQLTest_SETUP_Suite2
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Suite2'
   EXEC TST.Assert.Ignore 'Ignore Suite2. The entire suite will be ignored.'
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
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite2#TestA. This line should not be executed.'
   EXEC TST.Assert.Equals 'Passing Assert.Equals in SQLTest_Suite2#TestA', 1, 1
END
GO

CREATE PROCEDURE SQLTest_Suite2#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite2#TestB. This line should not be executed.'
   EXEC TST.Assert.Equals 'Failing Assert.Equals in SQLTest_Suite2#TestB', 1, 1
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
   EXEC TST.Assert.Ignore 'This will cause a failure. Ignore is not allowed in a suite teardown'
END
GO

CREATE PROCEDURE SQLTest_Suite3#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite3#TestA'
   EXEC TST.Assert.Equals 'Passing Assert.Equals in SQLTest_Suite3#TestA', 1, 1
END
GO

CREATE PROCEDURE SQLTest_Suite3#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite3#TestB'
   EXEC TST.Assert.Equals 'Failing Assert.Equals in SQLTest_Suite3#TestB', 1, 2
END
GO

USE tempdb
GO
