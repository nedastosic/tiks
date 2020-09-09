--===================================================================
-- FILE: SetTSTQuickStart.sql
-- This script will setup the TST Quick Start database: TSTQuickStart
-- This has code samples about using the TST package. 
-- ==================================================================

USE tempdb
GO

-- ==================================================================
-- Creates the TSTQuickStart database. 
-- If already exists then drops it first.
-- ==================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTQuickStart')
BEGIN
   DROP DATABASE TSTQuickStart
END

CREATE DATABASE TSTQuickStart
GO

USE TSTQuickStart
GO

-- ==================================================================
-- TSTConfig. TST calls this at the start of each test session 
-- to allow the test client to configure TST parameters.
-- ==================================================================
CREATE PROCEDURE dbo.TSTConfig
AS
BEGIN
   EXEC TST.Utils.SetConfiguration 
                     @ParameterName='UseTSTRollback', 
                     @ParameterValue='0', 
                     @Scope='Test', 
                     @ScopeValue='SQLTest_RolledBackOperation'
END
GO

-- ==================================================================
-- TABLE: Employee
-- Used in various functions and stored procedures that are 
-- written as examples.
-- ==================================================================
CREATE TABLE dbo.Employee(
   EmployeeId  int PRIMARY KEY IDENTITY(1,1) NOT NULL, 
   ManagerId   int NULL,                                 -- NULL only for the root level employee
   FirstName   nvarchar(255) NOT NULL,
   LastName    nvarchar(255) NOT NULL 
) 
GO

ALTER TABLE dbo.Employee ADD CONSTRAINT FK_Employee_ManagerId FOREIGN KEY(ManagerId) REFERENCES dbo.Employee(EmployeeId)
GO

-- ==================================================================
-- VIEW: SampleView 
-- This is a view that exemplifies how TST can be used to test a 
-- view. This view will return a dataset with the following 
-- schema and content:
--    Id [int]    Col1 [int]  Col2[varchar(10)]
--           1          NULL               NULL
--           2          NULL              'abc'
--           3             0               NULL
--           4             0              'abc'
--           5           123              'xyz'
-- ==================================================================
CREATE VIEW SampleView AS

         SELECT 1 AS Id,    NULL AS Col1,     NULL AS Col2
   UNION SELECT 2 AS Id,    NULL AS Col1,    'abc' AS Col2
   UNION SELECT 3 AS Id,       0 AS Col1,     NULL AS Col2
   UNION SELECT 4 AS Id,       0 AS Col1,    'abc' AS Col2
   UNION SELECT 5 AS Id,     123 AS Col1,    'xyz' AS Col2

GO

-- ==================================================================
-- PROCEDURE : AddEmployee
-- This stored procedure inserts a row in the Employee table. 
-- It will return in @EmployeeId the EmployeeId that was generated.
-- ==================================================================
CREATE PROCEDURE dbo.AddEmployee
   @ManagerId   int,
   @FirstName   nvarchar(255),
   @LastName    nvarchar(255), 
   @EmployeeId  int OUT
AS
BEGIN

   INSERT INTO dbo.Employee(ManagerId, FirstName, LastName) VALUES (@ManagerId, @FirstName, @LastName)
   SET @EmployeeId = SCOPE_IDENTITY()

END
GO

-- ==================================================================
-- PROCEDURE : DeleteEmployee
-- This stored procedure deletes a row from the Employee table. 
-- ==================================================================
CREATE PROCEDURE dbo.DeleteEmployee
   @EmployeeId  int
AS
BEGIN
   DELETE dbo.Employee WHERE EmployeeId  = @EmployeeId
END
GO

-- ==================================================================
-- PROCEDURE : UpdateEmployee
-- This stored procedure updates data about an rmployee
-- ==================================================================
CREATE PROCEDURE dbo.UpdateEmployee
   @EmployeeId  int,
   @FirstName   nvarchar(255),
   @LastName    nvarchar(255)
AS
BEGIN
   UPDATE dbo.Employee SET
      FirstName   = @FirstName,
      LastName    = @LastName
   WHERE EmployeeId  = @EmployeeId
END
GO

-- ==================================================================
-- PROCEDURE : RolledBackOperation
-- ==================================================================
CREATE PROCEDURE dbo.RolledBackOperation
AS
BEGIN

   BEGIN TRANSACTION 
   INSERT INTO dbo.Employee(ManagerId, FirstName, LastName) VALUES (NULL, 'James', 'Williams')
   ROLLBACK TRANSACTION 

END
GO

-- ==================================================================
-- PROCEDURE : RolledBackWithSavePoint
-- This is an alternative to RolledBackOperation that could unlike 
-- RolledBackOperation be tested without neededng to disable the 
-- TST Rollback. See SQLTest_RolledBackOperation
-- ==================================================================
CREATE PROCEDURE dbo.RolledBackWithSavePoint
AS
BEGIN

   SAVE TRANSACTION ProcedureSave
   INSERT INTO Employee(ManagerId, FirstName, LastName) VALUES (NULL, 'James', 'Williams')
   ROLLBACK TRANSACTION ProcedureSave

END
GO

-- ==================================================================
-- FUNCTION: QFn_TinyintToBinary
-- Converts a tinyint value int a string containing the equivalent 
-- binary value. For example converts 5 into '101'.
-- If @Value is NULL then the return value is NULL.
-- ==================================================================
CREATE FUNCTION dbo.QFn_TinyintToBinary (@Value tinyint) RETURNS varchar(8)
AS 
BEGIN

   DECLARE @BinaryString varchar(8)
   DECLARE @Crt2Power    tinyint

   SET @BinaryString = ''
   SET @Crt2Power = 128

   IF (@Value IS NULL)  RETURN NULL
   IF (@Value = 0)      RETURN '0'
   
   SET @BinaryString = ''

   WHILE (@Crt2Power > 0)
   BEGIN
      IF (@Value >= @Crt2Power) 
      BEGIN
         SET @BinaryString = @BinaryString + '1'; 
         SET @Value = @Value - @Crt2Power
      END
      ELSE
      BEGIN
         IF (@BinaryString != '') SET @BinaryString = @BinaryString + '0'; 
      END
      
      SET @Crt2Power = @Crt2Power / 2
   END
   
   RETURN @BinaryString
END
GO

-- ==================================================================
-- FUNCTION: QFn_GetSampleTable
-- This is a function that exemplifies how TST can be used to test a 
-- function that returns a table. This function will return a table 
-- with the following schema and content:
--    Id [int PK]    Col1 [int]  Col2[varchar(10)]
--              1          NULL               NULL
--              2          NULL              'abc'
--              3             0               NULL
--              4             0              'abc'
--              5           123              'xyz'
-- ==================================================================
CREATE FUNCTION QFn_GetSampleTable() 
RETURNS @SampleTable TABLE (
   Id    int PRIMARY KEY NOT NULL,
   Col1  int,
   Col2  varchar(10) )
AS 
BEGIN

   INSERT INTO @SampleTable (Id, Col1, Col2) VALUES(1, NULL,  NULL)
   INSERT INTO @SampleTable (Id, Col1, Col2) VALUES(2, NULL, 'abc')
   INSERT INTO @SampleTable (Id, Col1, Col2) VALUES(3,    0,  NULL)
   INSERT INTO @SampleTable (Id, Col1, Col2) VALUES(4,    0, 'abc')
   INSERT INTO @SampleTable (Id, Col1, Col2) VALUES(5,  123, 'xyz')

   RETURN
END
GO

-- ==================================================================
-- FUNCTION: QFn_GetEmployeeAllReports
-- This is a function that exemplifies how TST can be used to test a 
-- function that returns a table.
-- It will return a recordset with all the reports of a given manager.
-- If @ManagerId is NULL will return zero rows.
-- If @ManagerId is the Id of an employee that is not in the database 
--    will return zero rows.
-- If @ManagerId is the Id of an employee with no reports will return 
--    zero rows.
-- ==================================================================
CREATE FUNCTION QFn_GetEmployeeAllReports(@ManagerId int)
RETURNS @EmployeeAllReports TABLE (
   EmployeeId  int NOT NULL,
   FirstName   nvarchar(255) NOT NULL,
   LastName    nvarchar(255) NOT NULL )
AS
BEGIN

   WITH CTE_ReportInfo(EmployeeId, ManagerId, FirstName, LastName) AS (
      SELECT EmployeeId, ManagerId, FirstName, LastName
      FROM dbo.Employee 
      WHERE ManagerId = @ManagerId
      
      UNION ALL
      
      SELECT Employee.EmployeeId, Employee.ManagerId, Employee.FirstName, Employee.LastName
      FROM dbo.Employee 
      INNER JOIN CTE_ReportInfo ON 
         Employee.ManagerId = CTE_ReportInfo.EmployeeId
      )
   INSERT @EmployeeAllReports
   SELECT 
      CTE_ReportInfo.EmployeeId, CTE_ReportInfo.FirstName, CTE_ReportInfo.LastName
   FROM CTE_ReportInfo

   RETURN 

END
GO

-- ==================================================================
-- PROCEDURE: GetSampleTable
-- This is a stored procedure that exemplifies how TST can be used 
-- to test a stored procedure that returns a table. 
-- This function will return a table with the following schema and 
-- content:
--    Id [int PK]    Col1 [int]  Col2[varchar(10)]
--              1          NULL               NULL
--              2          NULL              'abc'
--              3             0               NULL
--              4             0              'abc'
--              5           123              'xyz'
-- ==================================================================
CREATE PROCEDURE GetSampleTable
AS
BEGIN
         SELECT 1, NULL,  NULL
   UNION SELECT 2, NULL, 'abc'
   UNION SELECT 3,    0,  NULL
   UNION SELECT 4,    0, 'abc'
   UNION SELECT 5,  123, 'xyz'

   RETURN
END
GO

-- ==================================================================
-- PROCEDURE: RaiseAnError 
-- This is a stored procedure that exemplifies 
-- the concept of "Expected Error".
-- If @Raise is 1 it will raise an error.
-- ==================================================================
CREATE PROCEDURE RaiseAnError 
   @Raise bit
AS
BEGIN
   IF (@Raise = 1)
   BEGIN
      RAISERROR('Test error', 16, 1)
   END
END
GO

-- ==================================================================
-- Creates the TEST stored procedures.
-- ==================================================================

-- ==================================================================
-- PROCEDURE SQLTest_SimplestTest
-- This sproc is a very simple example of a test stored procedure.
-- ==================================================================
CREATE PROCEDURE SQLTest_SimplestTest
AS
BEGIN
   DECLARE @Sum int 

   SET @Sum = 1 + 1
   EXEC TST.Assert.Equals '1+1 should be 2', 2, @Sum
END
GO

-- ==================================================================
-- PROCEDURE SQLTest_AssertSample
-- This sproc demonstrates simple usage of various Assert APIs.
-- ==================================================================
CREATE PROCEDURE SQLTest_AssertSample
AS
BEGIN

   DECLARE @Sum            int 
   DECLARE @DecimalValue   decimal(18,10)
   DECLARE @MoneyValue     money
   DECLARE @FloatValue     float
   DECLARE @SomeString     varchar(20)

   SET @Sum = 2 + 2
   EXEC TST.Assert.Equals     '2+2 should be 4'        , 4, @Sum
   EXEC TST.Assert.NotEquals  '2+2 should not be 5'    , 5, @Sum
   EXEC TST.Assert.IsNotNull  '@Sum should not be NULL', @Sum

   SET @Sum = 2 + NULL
   EXEC TST.Assert.IsNull     '@Sum should be NULL', @Sum

   SET @DecimalValue = 10.0 / 3.0
   EXEC TST.Assert.NumericEquals
      '10.0/3.0 should be approximately 3.33', 
      3.33, @DecimalValue, 0.01
   
   SET @MoneyValue = 1.0 / 3.0
   EXEC TST.Assert.NumericEquals
      '1.0/3.0 should be approximately 0.33', 
      0.33, @MoneyValue, 0.01

   SET @FloatValue = 1.002830959602E+26
   EXEC TST.Assert.FloatEquals 
      @ContextMessage = 'Atoms in one liter of water',  
      @ExpectedValue  = 1.00283e+026, 
      @ActualValue    = @FloatValue, 
      @Tolerance      = 0.00001e+026

   SET @SomeString = 'klm abc klm'
   EXEC TST.Assert.IsLike       
      '@SomeString should contain ''abc'' ', 
      '%abc%', 
      @SomeString
   
   EXEC TST.Assert.IsNotLike    
      '@SomeString should not contain ''xyz'' ', 
      '%xyz%', 
      @SomeString

END
GO

-- ==================================================================
-- PROCEDURE SQLTest_QFn_TinyintToBinary
-- Validates the behavior of QFn_TinyintToBinary.
-- ==================================================================
CREATE PROCEDURE SQLTest_QFn_TinyintToBinary
AS
BEGIN

   DECLARE @BinaryString varchar(8)

   SET @BinaryString = dbo.QFn_TinyintToBinary(NULL)
   EXEC TST.Assert.IsNull 'Case: NULL', @BinaryString

   SET @BinaryString = dbo.QFn_TinyintToBinary(0)
   EXEC TST.Assert.Equals 'Case: 0', '0', @BinaryString
   
   SET @BinaryString = dbo.QFn_TinyintToBinary(1)
   EXEC TST.Assert.Equals 'Case: 1', '1', @BinaryString

   SET @BinaryString = dbo.QFn_TinyintToBinary(2)
   EXEC TST.Assert.Equals 'Case: 2', '10', @BinaryString

   SET @BinaryString = dbo.QFn_TinyintToBinary(129)
   EXEC TST.Assert.Equals 'Case: 129', '10000001', @BinaryString

   SET @BinaryString = dbo.QFn_TinyintToBinary(254)
   EXEC TST.Assert.Equals 'Case: 254', '11111110', @BinaryString

   SET @BinaryString = dbo.QFn_TinyintToBinary(255)
   EXEC TST.Assert.Equals 'Case: 255', '11111111', @BinaryString
   
END
GO

-- ==================================================================
-- PROCEDURE SQLTest_QFn_GetSampleTable
-- This sproc validates the behavior of QFn_GetSampleTable
-- ==================================================================
CREATE PROCEDURE SQLTest_QFn_GetSampleTable
AS
BEGIN

   -- Create the temporary tables #ActualResult and #ExpectedResult
   CREATE TABLE #ExpectedResult (
      Id    int PRIMARY KEY NOT NULL,
      Col1  int,
      Col2  varchar(10)
   )

   CREATE TABLE #ActualResult (
      Id    int PRIMARY KEY NOT NULL,
      Col1  int,
      Col2  varchar(10)
   )
   
   -- Store the expected data in #ExpectedResult
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(1, NULL,  NULL)
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(2, NULL, 'abc')
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(3,    0,  NULL)
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(4,    0, 'abc')
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(5,  123, 'xyz')

   -- Store the actual data in #ActualResult
   INSERT INTO #ActualResult SELECT * FROM dbo.QFn_GetSampleTable()

   -- Assert.TableEquals compares the schema and content of tables 
   -- #ExpectedResult and #ActualResult.
   EXEC TST.Assert.TableEquals 'Some contextual message here'

END
GO

-- ==================================================================
-- PROCEDURE SQLTest_QFn_GetEmployeeAllReports
-- Validates the behavior of QFn_GetEmployeeAllReports
-- ==================================================================
CREATE PROCEDURE SQLTest_QFn_GetEmployeeAllReports
AS
BEGIN

   DECLARE @JamesWilliamsId         int
   DECLARE @MaryJonesId             int
   DECLARE @MichaelGarciaId         int
   DECLARE @LindaMooreId            int
   DECLARE @PatriciaMillerId        int
   DECLARE @RobertTaylorId          int
   DECLARE @BarbaraJacksonId        int
   DECLARE @JohnDavisId             int

   -- Remove all entries from the employee table.
   DELETE FROM dbo.Employee 

   -- Create the temporary tables #ActualResult and #ExpectedResult
   CREATE TABLE #ActualResult (
      EmployeeId  int PRIMARY KEY NOT NULL,
      FirstName   nvarchar(255) NOT NULL,
      LastName    nvarchar(255) NOT NULL)

   CREATE TABLE #ExpectedResult  (
      EmployeeId  int PRIMARY KEY NOT NULL,
      FirstName   nvarchar(255) NOT NULL,
      LastName    nvarchar(255) NOT NULL)
   
   -- Validate that when called on an empty table, QFn_GetEmployeeAllReports will return no rows.
   INSERT INTO #ActualResult SELECT * FROM dbo.QFn_GetEmployeeAllReports(-1)
   EXEC TST.Assert.IsTableEmpty 'Case: no employees'
   
   -- Add one employee.
   EXEC dbo.AddEmployee NULL, 'James', 'Williams', @JamesWilliamsId OUT

   -- Validate that when called on a one employee table, QFn_GetEmployeeAllReports will return no rows.
   INSERT INTO #ActualResult SELECT * FROM dbo.QFn_GetEmployeeAllReports(@JamesWilliamsId)
   EXEC TST.Assert.IsTableEmpty 'Case: one employee'
   
   -- Add more employees.
   EXEC dbo.AddEmployee @JamesWilliamsId , 'Mary'     , 'Jones'   , @MaryJonesId       OUT
   EXEC dbo.AddEmployee @MaryJonesId     , 'Michael'  , 'Garcia'  , @MichaelGarciaId   OUT
   EXEC dbo.AddEmployee @MaryJonesId     , 'Linda'    , 'Moore'   , @LindaMooreId      OUT
   EXEC dbo.AddEmployee @LindaMooreId    , 'Patricia' , 'Miller'  , @PatriciaMillerId  OUT
   EXEC dbo.AddEmployee @LindaMooreId    , 'Robert'   , 'Taylor'  , @RobertTaylorId    OUT
   EXEC dbo.AddEmployee @LindaMooreId    , 'Barbara'  , 'Jackson' , @BarbaraJacksonId  OUT
   EXEC dbo.AddEmployee @JamesWilliamsId , 'John'     , 'Davis'   , @JohnDavisId       OUT
 
  
   -- Validate the reports for James Williams.
   EXEC TST.Utils.DeleteTestTables

   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@MaryJonesId     , 'Mary'     , 'Jones'   )
   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@MichaelGarciaId , 'Michael'  , 'Garcia'  )
   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@LindaMooreId    , 'Linda'    , 'Moore'   )
   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@PatriciaMillerId, 'Patricia' , 'Miller'  )
   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@RobertTaylorId  , 'Robert'   , 'Taylor'  )
   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@BarbaraJacksonId, 'Barbara'  , 'Jackson' )
   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@JohnDavisId     , 'John'     , 'Davis'   )

   INSERT INTO #ActualResult
   SELECT * FROM dbo.QFn_GetEmployeeAllReports(@JamesWilliamsId)

   EXEC TST.Assert.TableEquals 'Reports of James Williams'
   
   -- Validate the reports for Mary Jones.
   EXEC TST.Utils.DeleteTestTables

   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@MichaelGarciaId , 'Michael'  , 'Garcia'  )
   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@LindaMooreId    , 'Linda'    , 'Moore'   )
   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@PatriciaMillerId, 'Patricia' , 'Miller'  )
   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@RobertTaylorId  , 'Robert'   , 'Taylor'  )
   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@BarbaraJacksonId, 'Barbara'  , 'Jackson' )
                                          
   INSERT INTO #ActualResult
   SELECT * FROM dbo.QFn_GetEmployeeAllReports(@MaryJonesId)

   EXEC TST.Assert.TableEquals 'Reports of Mary Jones'
   
   -- Validate the reports for Linda Moore
   EXEC TST.Utils.DeleteTestTables

   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@PatriciaMillerId, 'Patricia' , 'Miller'  )
   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@RobertTaylorId  , 'Robert'   , 'Taylor'  )
   INSERT INTO #ExpectedResult (EmployeeId, FirstName, LastName) VALUES (@BarbaraJacksonId, 'Barbara'  , 'Jackson' )

   INSERT INTO #ActualResult
   SELECT * FROM dbo.QFn_GetEmployeeAllReports(@LindaMooreId)

   EXEC TST.Assert.TableEquals 'Reports of Linda Moore'

   -- Validate the reports for Robert Taylor (no reports)
   EXEC TST.Utils.DeleteTestTables

   INSERT INTO #ActualResult
   SELECT * FROM dbo.QFn_GetEmployeeAllReports(@RobertTaylorId)
   
   EXEC TST.Assert.IsTableEmpty 'Reports of Robert Taylor'

   -- Validate the reports for an unknown employee (no reports)
   EXEC TST.Utils.DeleteTestTables

   INSERT INTO #ActualResult
   SELECT * FROM dbo.QFn_GetEmployeeAllReports(-1)
   
   EXEC TST.Assert.IsTableEmpty 'Reports of an unknown employee'

   -- Validate the reports for a NULL ManagerId
   EXEC TST.Utils.DeleteTestTables

   INSERT INTO #ActualResult
   SELECT * FROM dbo.QFn_GetEmployeeAllReports(NULL)
   
   EXEC TST.Assert.IsTableEmpty 'QFn_GetEmployeeAllReports called with NULL'

END
GO

-- ==================================================================
-- PROCEDURE SQLTest_GetSampleTable
-- This sproc validates the behavior of GetSampleTable
-- ==================================================================
CREATE PROCEDURE SQLTest_GetSampleTable
AS
BEGIN

   -- Create the temporary tables #ActualResult and #ExpectedResult
   CREATE TABLE #ExpectedResult (
      Id    int PRIMARY KEY NOT NULL,
      Col1  int,
      Col2  varchar(10)
   )

   CREATE TABLE #ActualResult (
      Id    int PRIMARY KEY NOT NULL,
      Col1  int,
      Col2  varchar(10)
   )
   
   -- Store the expected data in #ExpectedResult
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(1, NULL,  NULL)
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(2, NULL, 'abc')
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(3,    0,  NULL)
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(4,    0, 'abc')
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(5,  123, 'xyz')

   -- Store the actual data in #ExpectedResult
   INSERT INTO #ActualResult EXEC GetSampleTable 

   -- Assert.TableEquals compares the schema and content of tables 
   -- #ExpectedResult and #ActualResult.
   EXEC TST.Assert.TableEquals 'Some contextual message here'

END
GO

-- ==================================================================
-- PROCEDURE SQLTest_SampleView
-- This sproc validates the view SampleView
-- ==================================================================
CREATE PROCEDURE SQLTest_SampleView
AS
BEGIN

   -- Create the temporary tables #ActualResult and #ExpectedResult
   CREATE TABLE #ExpectedResult (
      Id    int PRIMARY KEY NOT NULL,
      Col1  int,
      Col2  varchar(10)
   )

   CREATE TABLE #ActualResult (
      Id    int PRIMARY KEY NOT NULL,
      Col1  int,
      Col2  varchar(10)
   )
   
   -- Store the expected data in #ExpectedResult
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(1, NULL,  NULL)
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(2, NULL, 'abc')
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(3,    0,  NULL)
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(4,    0, 'abc')
   INSERT INTO #ExpectedResult (Id, Col1, Col2) VALUES(5,  123, 'xyz')

   -- Store the actual data in #ExpectedResult
   INSERT INTO #ActualResult SELECT * FROM SampleView

   -- Assert.TableEquals compares the schema and content of tables 
   -- #ExpectedResult and #ActualResult.
   EXEC TST.Assert.TableEquals 'Some contextual message here'

END
GO

-- ==================================================================
-- PROCEDURE SQLTest_ExpectedError
-- This sproc demonstrates the concept of "expected error".
-- ==================================================================
CREATE PROCEDURE SQLTest_ExpectedError
AS
BEGIN

   EXEC TST.Assert.RegisterExpectedError 
      @ContextMessage         = 'Testing RaiseAnError',
      @ExpectedErrorMessage   = 'Test error'
   
   -- RaiseAnError will execute: RAISERROR('Test error', 16, 1)
   EXEC dbo.RaiseAnError @Raise = 1

END
GO

-- ==================================================================
-- PROCEDURE SQLTest_RolledBackOperation
-- This sproc demonstrates the test of a code that uses 
-- BEGIN TRANSACTION/ROLLBACK TRANSACTION. Used in conjunction with 
-- the TSTConfig stored procedure
-- ==================================================================
CREATE PROCEDURE SQLTest_RolledBackOperation
AS
BEGIN

   DECLARE @EmployeeCountBefore int
   DECLARE @EmployeeCountAfter  int

   SELECT @EmployeeCountBefore = COUNT(*) FROM dbo.Employee
   EXEC dbo.RolledBackOperation
   SELECT @EmployeeCountAfter  = COUNT(*) FROM dbo.Employee

   EXEC TST.Assert.Equals 'RolledBackOperation should not change the employee count', @EmployeeCountBefore, @EmployeeCountAfter

END
GO

-- ==================================================================
-- PROCEDURE: SQLTest_SETUP_EmployeeOperations
-- This sproc demonstrates how tests can be grouped in suites. 
-- This procedure is the setup of a suite called EmployeeOperations.
-- ==================================================================
CREATE PROCEDURE SQLTest_SETUP_EmployeeOperations
AS 
BEGIN
   DECLARE @TomJohnsonId int
   
   -- Remove all entries from the employee table.
   DELETE FROM dbo.Employee 

   -- Add one employee.
   EXEC dbo.AddEmployee NULL, 'Tom', 'Johnson', @TomJohnsonId OUT
END
GO

-- ==================================================================
-- PROCEDURE: SQLTest_EmployeeOperations#DeleteEmployee
-- This sproc demonstrates how tests can be grouped in suites. 
-- This procedure is one of the tests that belong to a suite 
-- called EmployeeOperations.
-- ==================================================================
CREATE PROCEDURE SQLTest_EmployeeOperations#DeleteEmployee
AS 
BEGIN
   DECLARE @TomJohnsonId int

   -- Get the Id of Tom Johnson
   SET @TomJohnsonId = NULL
   SELECT @TomJohnsonId = EmployeeId FROM dbo.Employee 
   WHERE FirstName = 'Tom' AND LastName = 'Johnson'

   EXEC TST.Assert.IsNotNull 'The setup should insert data for Tom Johnson', @TomJohnsonId

   -- Delete Tom Johnson
   EXEC dbo.DeleteEmployee @TomJohnsonId

   -- Get the again the Id of Tom Johnson. This time the record shoudl be gone
   SET @TomJohnsonId = NULL
   SELECT @TomJohnsonId = EmployeeId FROM dbo.Employee 
   WHERE FirstName = 'Tom' AND LastName = 'Johnson'
   
   EXEC TST.Assert.IsNull 'After deleting an employee its Id should be returned as NULL', @TomJohnsonId
END
GO

-- ==================================================================
-- PROCEDURE: SQLTest_EmployeeOperations#UpdateEmployee
-- This sproc demonstrates how tests can be grouped in suites. 
-- This procedure is one of the tests that belong to a suite 
-- called EmployeeOperations.
-- ==================================================================
CREATE PROCEDURE SQLTest_EmployeeOperations#UpdateEmployee
AS 
BEGIN
   DECLARE @EmployeeId int

   -- Get the Id of Tom Johnson
   SET @EmployeeId = NULL
   SELECT @EmployeeId = EmployeeId FROM dbo.Employee 
   WHERE FirstName = 'Tom' AND LastName = 'Johnson'

   EXEC TST.Assert.IsNotNull 'The setup should insert data for Tom Johnson', @EmployeeId

   -- Change the name Tom Johnson to Thomas Jones
   EXEC dbo.UpdateEmployee @EmployeeId, 'Thomas', 'Jones'

   -- Get the again the Id this time of Thomas Jones.
   SET @EmployeeId = NULL
   SELECT @EmployeeId = EmployeeId FROM dbo.Employee 
   WHERE FirstName = 'Thomas' AND LastName = 'Jones'
   
   EXEC TST.Assert.IsNotNull 'The update operation should have changed the name of the employee', @EmployeeId
   
END
GO

USE tempdb
GO
