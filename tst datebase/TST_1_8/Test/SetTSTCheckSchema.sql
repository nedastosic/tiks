--===================================================================
-- FILE: SetTSTCheckSchema.sql
-- This script will setup one of the databases used to test the 
-- TST infrastructure.
-- This is a database that has no TST suites or tests.
-- ==================================================================

USE tempdb
GO

-- =======================================================================
-- Creates the TSTCheckSchema Database. If already exists then drops it first.
-- =======================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckSchema')
BEGIN
   DROP DATABASE TSTCheckSchema
END

CREATE DATABASE TSTCheckSchema
GO

USE TSTCheckSchema
GO

CREATE SCHEMA TestSchema1
GO

CREATE SCHEMA TestSchema2
GO

CREATE SCHEMA TestSchema3
GO

CREATE SCHEMA TestSchema4
GO

CREATE SCHEMA TestSchema5
GO

CREATE SCHEMA TestSchema6
GO

CREATE SCHEMA TestSchema7
GO

CREATE SCHEMA TestSchemaX1
GO

CREATE SCHEMA TestSchemaX2
GO

CREATE SCHEMA TestSchemaX3
GO

CREATE SCHEMA TestSchemaX4
GO


CREATE PROCEDURE TestSchema1.SQLTest_SETUP_Suite1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchema1.SQLTest_SETUP_Suite1'
END
GO

CREATE PROCEDURE TestSchema1.SQLTest_TEARDOWN_Suite1
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchema1.SQLTest_TEARDOWN_Suite1'
END
GO

CREATE PROCEDURE TestSchema1.SQLTest_Suite1#Test1_A
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchema1.SQLTest_Suite1#Test1_A'
   EXEC TST.Assert.Equals 'Failing test in TestSchema1.SQLTest_Suite1#Test1_A', 1, 0
END
GO

CREATE PROCEDURE TestSchema1.SQLTest_Suite1#Test1_B
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchema1.SQLTest_Suite1#Test1_B'
   EXEC TST.Assert.Equals 'Passing test in TestSchema1.SQLTest_Suite1#Test1_B', 1, 1
END
GO


CREATE PROCEDURE TestSchema2.SQLTest_SETUP_SuiteA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchema2.SQLTest_SETUP_Suite1'
END
GO

CREATE PROCEDURE TestSchema2.SQLTest_TEARDOWN_SuiteA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchema2.SQLTest_TEARDOWN_Suite1'
END
GO

CREATE PROCEDURE TestSchema2.SQLTest_SuiteA#Test2_A
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchema2.SQLTest_Suite1#Test2_A'
END
GO

CREATE PROCEDURE TestSchema3.SQLTest_SETUP_SuiteA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchema3.SQLTest_SETUP_Suite1'
END
GO

CREATE PROCEDURE TestSchema3.SQLTest_TEARDOWN_SuiteA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchema3.SQLTest_TEARDOWN_Suite1'
END
GO

CREATE PROCEDURE TestSchema3.SQLTest_SuiteA#Test3_A
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchema3.SQLTest_Suite1#Test3_A'
END
GO

CREATE PROCEDURE TestSchema4.SQLTest_SuiteB#Test4_A
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchema4.SQLTest_SuiteA#Test4_A'
END
GO

CREATE PROCEDURE TestSchema5.SQLTest_SuiteB#Test5_A
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchema5.SQLTest_SuiteA#Test5_A'
END
GO

CREATE PROCEDURE TestSchema6.SQLTest_TestX
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchema6.SQLTest_TestX'
END
GO

CREATE PROCEDURE TestSchema7.SQLTest_TestX
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchema7.SQLTest_TestX'
END
GO


CREATE PROCEDURE TestSchemaX1.SQLTest_SETUP_SuiteX
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchemaX1.SQLTest_SETUP_SuiteX'
END
GO

CREATE PROCEDURE TestSchemaX2.SQLTest_TEARDOWN_SuiteX
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchemaX2.SQLTest_TEARDOWN_SuiteX'
END
GO

CREATE PROCEDURE TestSchemaX3.SQLTest_SuiteX#TestA
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchemaX3.SQLTest_SuiteX#TestA'
   EXEC TST.Assert.Equals 'Test passing Assert.Equals', 1, 1
END
GO

CREATE PROCEDURE TestSchemaX4.SQLTest_SuiteX#TestB
AS
BEGIN
   EXEC TST.Assert.LogInfo 'This is TestSchemaX4.SQLTest_SuiteX#TestB'
   EXEC TST.Assert.Equals 'Test passing Assert.Equals', 1, 1
END
GO


USE tempdb
GO
