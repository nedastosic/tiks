--===================================================================
-- FILE: SetTSTCheckTestSessionErr.sql
-- This script will setup a simple TST test database.
-- This database will be used to automate part of the self check 
-- scripts.
-- ==================================================================

USE tempdb
GO

-- ==================================================================
-- Creates the TSTCheckTestSessionErrX databases. 
-- If they already exist then drops them first.
-- ==================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckTestSessionErr0')
BEGIN
   DROP DATABASE TSTCheckTestSessionErr0
END
CREATE DATABASE TSTCheckTestSessionErr0
GO
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckTestSessionErr1')
BEGIN
   DROP DATABASE TSTCheckTestSessionErr1
END
CREATE DATABASE TSTCheckTestSessionErr1
GO
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckTestSessionErr2')
BEGIN
   DROP DATABASE TSTCheckTestSessionErr2
END
CREATE DATABASE TSTCheckTestSessionErr2
GO
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckTestSessionErr3')
BEGIN
   DROP DATABASE TSTCheckTestSessionErr3
END
CREATE DATABASE TSTCheckTestSessionErr3
GO
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckTestSessionErr4')
BEGIN
   DROP DATABASE TSTCheckTestSessionErr4
END
CREATE DATABASE TSTCheckTestSessionErr4
GO
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckTestSessionErr5')
BEGIN
   DROP DATABASE TSTCheckTestSessionErr5
END
CREATE DATABASE TSTCheckTestSessionErr5
GO
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckTestSessionErr6')
BEGIN
   DROP DATABASE TSTCheckTestSessionErr6
END
CREATE DATABASE TSTCheckTestSessionErr6
GO
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckTestSessionErr7')
BEGIN
   DROP DATABASE TSTCheckTestSessionErr7
END
CREATE DATABASE TSTCheckTestSessionErr7
GO
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckTestSessionErr8')
BEGIN
   DROP DATABASE TSTCheckTestSessionErr8
END
CREATE DATABASE TSTCheckTestSessionErr8
GO

-- ==================================================================
-- The case where the test session will pass
-- ==================================================================

USE TSTCheckTestSessionErr0
GO

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

CREATE PROCEDURE SQLTest_Test1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Test1'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Test1', 1, 1
END
GO

-- ==================================================================
-- The case where the test session setup has a failing assert
-- ==================================================================

USE TSTCheckTestSessionErr1
GO

CREATE PROCEDURE SQLTest_SESSION_SETUP @TestSessionId int
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_SETUP'
   EXEC TST.Assert.Equals 'Failing test in SQLTest_SESSION_SETUP', 1, 2
   EXEC TST.Assert.LogInfo 'This log should not be executed'
END
GO

CREATE PROCEDURE SQLTest_SESSION_TEARDOWN @TestSessionId int
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_TEARDOWN'
END
GO

CREATE PROCEDURE SQLTest_Test1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This log should not be executed'
END
GO

-- ==================================================================
-- The case where the test session setup registers an 
-- expected error which is illegal.
-- ==================================================================

USE TSTCheckTestSessionErr2
GO

CREATE PROCEDURE SQLTest_SESSION_SETUP @TestSessionId int
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_SETUP'
   EXEC TST.Assert.RegisterExpectedError 
      @ContextMessage               = 'This call will trigger an error',
      @ExpectedErrorMessage         = 'Test error',
      @ExpectedErrorProcedure       = 'RaiseAnError',
      @ExpectedErrorNumber          = 50000
   EXEC TST.Assert.LogInfo  'This log should not be executed'
END
GO

CREATE PROCEDURE SQLTest_SESSION_TEARDOWN @TestSessionId int
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_TEARDOWN'
END
GO

CREATE PROCEDURE SQLTest_Test1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This log should not be executed'
END
GO

-- ==================================================================
-- The case where the test session setup has a runtime error.
-- ==================================================================

USE TSTCheckTestSessionErr3
GO

CREATE PROCEDURE SQLTest_SESSION_SETUP @TestSessionId int
AS
BEGIN
   DECLARE @TempVar int

   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_SETUP'
   SET @TempVar = ISNULL(@TempVar, 'null');  -- This will generate a run-time error
   EXEC TST.Assert.LogInfo 'This log should not be executed'
END
GO

CREATE PROCEDURE SQLTest_SESSION_TEARDOWN @TestSessionId int
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_TEARDOWN'
END
GO

CREATE PROCEDURE SQLTest_Test1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This log should not be executed'
END
GO

-- ==================================================================
-- The case where the test session teardown has a failing assert
-- ==================================================================

USE TSTCheckTestSessionErr4
GO

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
   EXEC TST.Assert.Equals 'Failing test in SQLTest_SESSION_TEARDOWN', 1, 2
   EXEC TST.Assert.LogInfo 'This log should not be executed'
END
GO

CREATE PROCEDURE SQLTest_Test1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Test1'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Test1', 1, 1
END
GO

-- ==================================================================
-- The case where the test session teardown registers an 
-- expected error which is illegal.
-- ==================================================================

USE TSTCheckTestSessionErr5
GO

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
   EXEC TST.Assert.RegisterExpectedError 
      @ContextMessage               = 'This call will trigger an error',
      @ExpectedErrorMessage         = 'Test error',
      @ExpectedErrorProcedure       = 'RaiseAnError',
      @ExpectedErrorNumber          = 50000
   EXEC TST.Assert.LogInfo  'This log should not be executed'
END
GO

CREATE PROCEDURE SQLTest_Test1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Test1'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Test1', 1, 1
END
GO

-- ==================================================================
-- The case where the test session teardown has a runtime error.
-- ==================================================================

USE TSTCheckTestSessionErr6
GO

CREATE PROCEDURE SQLTest_SESSION_SETUP @TestSessionId int
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_SETUP'
END
GO

CREATE PROCEDURE SQLTest_SESSION_TEARDOWN @TestSessionId int
AS
BEGIN
   DECLARE @TempVar int

   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_TEARDOWN'
   SET @TempVar = ISNULL(@TempVar, 'null');  -- This will generate a run-time error
   EXEC TST.Assert.LogInfo 'This log should not be executed'   
END
GO

CREATE PROCEDURE SQLTest_Test1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Test1'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Test1', 1, 1
END
GO

-- ==================================================================
-- The case where there are two test session setup procedures.
-- ==================================================================

USE TSTCheckTestSessionErr7
GO

CREATE SCHEMA TestSchema1
GO
CREATE SCHEMA TestSchema2
GO


CREATE PROCEDURE TestSchema1.SQLTest_SESSION_SETUP
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_SETUP'
END
GO

CREATE PROCEDURE TestSchema2.SQLTest_SESSION_SETUP
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_SETUP'
END
GO

CREATE PROCEDURE SQLTest_Test1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Test1'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Test1', 1, 1
END
GO

-- ==================================================================
-- The case where there are two test session teardown procedures.
-- ==================================================================

USE TSTCheckTestSessionErr8
GO

CREATE SCHEMA TestSchema1
GO
CREATE SCHEMA TestSchema2
GO


CREATE PROCEDURE TestSchema1.SQLTest_SESSION_TEARDOWN
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_TEARDOWN'
END
GO

CREATE PROCEDURE TestSchema2.SQLTest_SESSION_TEARDOWN
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_SESSION_TEARDOWN'
END
GO

CREATE PROCEDURE SQLTest_Test1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is SQLTest_Test1'
   EXEC TST.Assert.Equals 'Passing test in SQLTest_Test1', 1, 1
END
GO

USE tempdb
GO
