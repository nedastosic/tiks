--===================================================================
-- FILE: SetTSTCheckNoTests.sql
-- This script will setup one of the databases used to test the 
-- TST infrastructure.
-- This is a database that has no TST suites or tests.
-- ==================================================================

USE tempdb
GO

-- =======================================================================
-- Creates the TSTCheckNoTests Database. If already exists then drops it first.
-- =======================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckNoTests')
BEGIN
   DROP DATABASE TSTCheckNoTests
END

CREATE DATABASE TSTCheckNoTests
GO

USE TSTCheckNoTests
GO


-- =======================================================================
-- The actual functions and stored procedures
-- =======================================================================
GO

CREATE FUNCTION dbo.SVFn_AddTwoNumbers(@A int, @B int) RETURNS int
AS
BEGIN
   RETURN @A + @B
END
GO

CREATE PROCEDURE SV_GenerateSquence
AS
BEGIN
   
   PRINT 'This is SV_GenerateSquence'

   SELECT 1
   UNION SELECT 2
   UNION SELECT 3
   UNION SELECT 4
   UNION SELECT 5

END
GO

USE tempdb
GO
