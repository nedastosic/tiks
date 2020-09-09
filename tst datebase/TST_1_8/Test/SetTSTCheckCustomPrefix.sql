--===================================================================
-- FILE: SetTSTCheckCustomPrefix.sql
-- This script will setup a simple TST test database.
-- This database will be used to automate part of the self check 
-- scripts.
-- ==================================================================

USE tempdb
GO

-- ==================================================================
-- Creates the TSTCheckCustomPrefix database. 
-- If already exists then drops it first.
-- ==================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckCustomPrefix')
BEGIN
   DROP DATABASE TSTCheckCustomPrefix
END

CREATE DATABASE TSTCheckCustomPrefix
GO

USE TSTCheckCustomPrefix
GO

-- =======================================================================
-- TABLE: TestParameters
-- This table contains a flag that signals to dbo.TSTConfig if needs 
-- to register a custom prefix
-- =======================================================================
CREATE TABLE dbo.TestParameters
(
   PrefixDatabaseName   sysname NULL,
   CustomPrefix         varchar(100) NOT NULL
)
GO

CREATE PROCEDURE dbo.TSTConfig
AS
BEGIN

   DECLARE @PrefixDatabaseName   sysname
   DECLARE @CustomPrefix         varchar(100)

   SET @CustomPrefix = NULL
   SELECT TOP 1
      @PrefixDatabaseName = PrefixDatabaseName,
      @CustomPrefix       = CustomPrefix
   FROM dbo.TestParameters
   WHERE PrefixDatabaseName IS NULL

   IF (@CustomPrefix IS NOT NULL)
   BEGIN 
      EXEC TST.Utils.SetTSTVariable @PrefixDatabaseName, 'SqlTestPrefix', @CustomPrefix
   END

   SET @CustomPrefix = NULL
   SELECT TOP 1
      @PrefixDatabaseName = PrefixDatabaseName,
      @CustomPrefix       = CustomPrefix
   FROM dbo.TestParameters
   WHERE PrefixDatabaseName IS NOT NULL

   IF (@CustomPrefix IS NOT NULL)
   BEGIN 
      EXEC TST.Utils.SetTSTVariable @PrefixDatabaseName, 'SqlTestPrefix', @CustomPrefix
   END

   EXEC TST.Utils.SetConfiguration 
                     @ParameterName='UseTSTRollback', 
                     @ParameterValue='0', 
                     @Scope='Suite', 
                     @ScopeValue='Suite2'
END
GO

CREATE PROCEDURE ST_SESSION_SETUP @TestSessionId int
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is ST_SESSION_SETUP'
END
GO

CREATE PROCEDURE ST_SESSION_TEARDOWN @TestSessionId int
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is ST_SESSION_TEARDOWN'
END
GO

CREATE PROCEDURE dbo.ST_TestEqualsFails
AS
BEGIN
   EXEC TST.Assert.Equals 'Test Assert.Equals in ST_TestEqualsFails', 1, 2
END
GO

CREATE PROCEDURE dbo.ST_TestEqualsOK
AS
BEGIN
   EXEC TST.Assert.Equals 'Test Assert.Equals in ST_TestEqualsOK', 1, 1
END
GO


CREATE PROCEDURE ST_SETUP_Suite1
AS
BEGIN
   EXEC TST.Assert.Equals 'Test @@TRANCOUNT in ST_SETUP_Suite1', 1, @@TRANCOUNT
END
GO

CREATE PROCEDURE ST_TEARDOWN_Suite1
AS
BEGIN
   EXEC TST.Assert.Equals 'Test @@TRANCOUNT in ST_TEARDOWN_Suite1', 1, @@TRANCOUNT
END
GO

CREATE PROCEDURE ST_Suite1#TestA
AS
BEGIN
   EXEC TST.Assert.Equals 'Test @@TRANCOUNT in ST_Suite1#TestA', 1, @@TRANCOUNT
END
GO

CREATE PROCEDURE ST_Suite1#TestB
AS
BEGIN
   EXEC TST.Assert.Equals 'Test @@TRANCOUNT in ST_Suite1#TestB', 1, @@TRANCOUNT
END
GO


CREATE PROCEDURE ST_SETUP_Suite2
AS
BEGIN
   EXEC TST.Assert.Equals 'Test @@TRANCOUNT in ST_SETUP_Suite2', 0, @@TRANCOUNT
END
GO

CREATE PROCEDURE ST_TEARDOWN_Suite2
AS
BEGIN
   EXEC TST.Assert.Equals 'Test @@TRANCOUNT in ST_TEARDOWN_Suite2', 0, @@TRANCOUNT
END
GO

CREATE PROCEDURE ST_Suite2#TestA
AS
BEGIN
   EXEC TST.Assert.Equals 'Test @@TRANCOUNT in ST_Suite2#TestA', 0, @@TRANCOUNT
END
GO

CREATE PROCEDURE ST_Suite2#TestB
AS
BEGIN
   EXEC TST.Assert.Equals 'Test @@TRANCOUNT in ST_Suite2#TestB', 0, @@TRANCOUNT
END
GO


USE tempdb
GO
