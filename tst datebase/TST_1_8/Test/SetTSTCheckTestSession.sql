--===================================================================
-- FILE: SetTSTCheckTestSession.sql
-- This script will setup a simple TST test database.
-- This database will be used to automate part of the self check 
-- scripts.
-- ==================================================================

USE tempdb
GO

-- ==================================================================
-- Creates the TSTCheckTestSession database. 
-- If already exists then drops it first.
-- ==================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckTestSession')
BEGIN
   DROP DATABASE TSTCheckTestSession
END

CREATE DATABASE TSTCheckTestSession
GO

USE TSTCheckTestSession
GO

-- ==================================================================
-- The session setup.
-- ==================================================================

CREATE PROCEDURE SQLTest_SESSION_SETUP @TestSessionId int
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_SETUP'
END
GO

CREATE PROCEDURE SQLTest_SESSION_TEARDOWN @TestSessionId int
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_TEARDOWN'
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
   EXEC TST.Assert.Equals 'Failing test in SQLTest_Suite2#TestA', 1, 2
   EXEC TST.Assert.LogInfo 'This log should not be executed'
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
-- Suite3
-- ==================================================================

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
   EXEC TST.Assert.LogInfo 'This log should not be executed'
END
GO

CREATE PROCEDURE SQLTest_Suite3#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite3#TestB'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Suite3#TestB', 1, 1
END
GO

-- ==================================================================
-- Suite4
-- ==================================================================

CREATE PROCEDURE SQLTest_SETUP_Suite4
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Suite4'
   EXEC TST.Assert.Equals  'Failing test in SQLTest_SETUP_Suite4', 1, 2
   EXEC TST.Assert.LogInfo 'This log should not be executed'
END
GO

CREATE PROCEDURE SQLTest_TEARDOWN_Suite4
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Suite4'
END
GO

CREATE PROCEDURE SQLTest_Suite4#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite4#TestA'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Suite4#TestA', 1, 1
END
GO

CREATE PROCEDURE SQLTest_Suite4#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite4#TestB'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Suite4#TestB', 1, 1
END
GO

-- ==================================================================
-- Suite5
-- ==================================================================

CREATE PROCEDURE SQLTest_SETUP_Suite5
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Suite5'

   EXEC TST.Assert.RegisterExpectedError 
      @ContextMessage               = 'This call will trigger an error',
      @ExpectedErrorMessage         = 'Test error',
      @ExpectedErrorProcedure       = 'RaiseAnError',
      @ExpectedErrorNumber          = 50000
      
   EXEC TST.Assert.LogInfo  'This log should not be executed'
END
GO

CREATE PROCEDURE SQLTest_TEARDOWN_Suite5
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Suite5'
END
GO

CREATE PROCEDURE SQLTest_Suite5#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite5#TestA'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Suite5#TestA', 1, 1
END
GO

CREATE PROCEDURE SQLTest_Suite5#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite5#TestB'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Suite5#TestB', 1, 1
END
GO

-- ==================================================================
-- Suite6
-- ==================================================================

CREATE PROCEDURE SQLTest_SETUP_Suite6
AS
BEGIN
   DECLARE @TempVar int

   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Suite6'
   SET @TempVar = ISNULL(@TempVar, 'null');  -- This will generate a run-time error
   EXEC TST.Assert.LogInfo 'This log should not be executed'
END
GO

CREATE PROCEDURE SQLTest_TEARDOWN_Suite6
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Suite6'
END
GO

CREATE PROCEDURE SQLTest_Suite6#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite6#TestA'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Suite6#TestA', 1, 1
END
GO

CREATE PROCEDURE SQLTest_Suite6#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite6#TestB'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Suite6#TestB', 1, 1
END
GO

-- ==================================================================
-- Suite7
-- ==================================================================

CREATE PROCEDURE SQLTest_SETUP_Suite7
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Suite7'
END
GO

CREATE PROCEDURE SQLTest_TEARDOWN_Suite7
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Suite7'
   EXEC TST.Assert.Equals  'Failing test in SQLTest_TEARDOWN_Suite7', 1, 2
   EXEC TST.Assert.LogInfo 'This log should not be executed'
END
GO

CREATE PROCEDURE SQLTest_Suite7#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite7#TestA'
   EXEC TST.Assert.Equals 'Failing test in SQLTest_Suite7#TestA', 1, 2
END
GO

CREATE PROCEDURE SQLTest_Suite7#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite7#TestB'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Suite7#TestB', 1, 1
END
GO

-- ==================================================================
-- Suite8
-- ==================================================================

CREATE PROCEDURE SQLTest_SETUP_Suite8
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Suite8'
END
GO

CREATE PROCEDURE SQLTest_TEARDOWN_Suite8
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Suite8'

   EXEC TST.Assert.RegisterExpectedError 
      @ContextMessage               = 'This call will trigger an error',
      @ExpectedErrorMessage         = 'Test error',
      @ExpectedErrorProcedure       = 'RaiseAnError',
      @ExpectedErrorNumber          = 50000

   EXEC TST.Assert.LogInfo 'This log should not be executed'
END
GO

CREATE PROCEDURE SQLTest_Suite8#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite8#TestA'
   EXEC TST.Assert.Equals 'Failing test in SQLTest_Suite8#TestA', 1, 2
END
GO

CREATE PROCEDURE SQLTest_Suite8#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite8#TestB'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Suite8#TestB', 1, 1
END
GO

-- ==================================================================
-- Suite9
-- ==================================================================

CREATE PROCEDURE SQLTest_SETUP_Suite9
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SETUP_Suite9'
END
GO

CREATE PROCEDURE SQLTest_TEARDOWN_Suite9
AS
BEGIN
   DECLARE @TempVar int

   EXEC TST.Assert.LogInfo 'This is SQLTest_TEARDOWN_Suite9'

   SET @TempVar = ISNULL(@TempVar, 'null');  -- This will generate a run-time error
   EXEC TST.Assert.LogInfo 'This log should not be executed'
END
GO

CREATE PROCEDURE SQLTest_Suite9#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite9#TestA'
   EXEC TST.Assert.Equals 'Failing test in SQLTest_Suite9#TestA', 1, 2
END
GO

CREATE PROCEDURE SQLTest_Suite9#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Suite9#TestB'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Suite9#TestB', 1, 1
END
GO

-- ==================================================================
-- The Anonymous Suite
-- ==================================================================


CREATE PROCEDURE SQLTest_Test1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Test1'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Test1', 1, 1
END
GO

CREATE PROCEDURE SQLTest_Test2
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Test2'
   EXEC TST.Assert.Equals 'Failing test in SQLTest_Test2', 1, 2
   EXEC TST.Assert.LogInfo 'This log should not be executed'
END
GO

CREATE PROCEDURE SQLTest_Test3
AS
BEGIN
   DECLARE @TempVar int

   EXEC TST.Assert.LogInfo 'This is SQLTest_Test3'
   SET @TempVar = ISNULL(@TempVar, 'null');  -- This will generate a run-time error
   EXEC TST.Assert.LogInfo 'This log should not be executed'
END
GO


USE tempdb
GO
