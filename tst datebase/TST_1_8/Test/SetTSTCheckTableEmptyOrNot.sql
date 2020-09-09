--===================================================================
-- FILE: SetTSTCheckTableEmptyOrNot.sql
-- This script will setup a simple TST test database.
-- This database will be used to automate part of the self check 
-- scripts.
-- ==================================================================

USE tempdb
GO

-- ==================================================================
-- Creates the TSTCheckTableEmptyOrNot database. 
-- If already exists then drops it first.
-- ==================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckTableEmptyOrNot')
BEGIN
   DROP DATABASE TSTCheckTableEmptyOrNot
END

CREATE DATABASE TSTCheckTableEmptyOrNot
GO

USE TSTCheckTableEmptyOrNot
GO


-- =======================================================================
-- The TST test stored procedures
-- =======================================================================

CREATE PROCEDURE dbo.SQLTest_IsTableNotEmptyPass
AS
BEGIN

   CREATE TABLE #ActualResult   (Test int)
   INSERT INTO #ActualResult VALUES (1)

   EXEC TST.Assert.IsTableNotEmpty 'Test Assert.IsTableNotEmpty in SQLTest_IsTableNotEmptyPass'

END
GO

CREATE PROCEDURE dbo.SQLTest_IsTableNotEmptyFail
AS
BEGIN

   CREATE TABLE #ActualResult   (Test int)

   EXEC TST.Assert.IsTableNotEmpty 'Test Assert.IsTableNotEmpty in SQLTest_IsTableNotEmptyFail'

END
GO

CREATE PROCEDURE dbo.SQLTest_IsTableNotEmptyNoActualTableCreated
AS
BEGIN

   EXEC TST.Assert.IsTableNotEmpty 'Test Assert.IsTableNotEmpty in SQLTest_IsTableNotEmptyNoActualTableCreated'

END
GO

CREATE PROCEDURE dbo.SQLTest_IsTableEmptyPass
AS
BEGIN

   CREATE TABLE #ActualResult   (Test int)

   EXEC TST.Assert.IsTableEmpty 'Test Assert.IsTableEmpty in SQLTest_IsTableEmptyPass'

END
GO

CREATE PROCEDURE dbo.SQLTest_IsTableEmptyFail
AS
BEGIN

   CREATE TABLE #ActualResult   (Test int)
   INSERT INTO #ActualResult VALUES (1)

   EXEC TST.Assert.IsTableEmpty 'Test Assert.IsTableEmpty in SQLTest_IsTableEmptyFail'

END
GO

CREATE PROCEDURE dbo.SQLTest_IsTableEmptyNoActualTableCreated
AS
BEGIN

   EXEC TST.Assert.IsTableEmpty 'Test Assert.IsTableEmpty in SQLTest_IsTableEmptyNoActualTableCreated'

END
GO

USE tempdb
GO
