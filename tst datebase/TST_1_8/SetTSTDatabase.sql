--===================================================================
-- FILE: SetTSTDatabase.sql
-- This is the SQL script that will setup the TST support 
-- database. It must be invoked by TST.bat
-- Licence:
-- This project is released under the 
--    "Eclipse Public License - v 1.0"
--    See http://www.eclipse.org/legal/epl-v10.html
-- History:
-- ------------------------------------------------------------------
-- 02/28/2009 - Ladislau Molnar
--              Version 1.0 is finalized
-- 03/01/2009 - Ladislau Molnar
--              The project is released on Codeplex: 
--              http://www.codeplex.com/
-- 04/19/2009 - Ladislau Molnar
--              Version 1.1 is finalized
--              Support for writing test sprocs in their own schema.
--              Test results are in alphabetical order of Suites/Tests.
-- 05/17/2009 - Ladislau Molnar
--              Version 1.2 is finalized
--              Allow Assert.TableEquals to ignore columns as specified 
--              in an optional parameter.
-- 07/22/2009 - Ladislau Molnar
--              Version 1.3 is finalized
--              Add a new view: Data.TSTResultsEx to facilitate the integration 
--              with http://www.codeplex.com/MCI4TST. 
--              Data.TSTResultsEx provides more details about the results of a 
--              test session compared with the existing view: Data.TSTResults.
-- 09/23/2009 - Ladislau Molnar
--              Version 1.4 is finalized
--              V 1.3 or earlier will not install on a SQL Server with a case sensitive collation. 
--              The V1.4 release fixes all known issues related to case sensitive collations
-- 03/17/2010 - Ladislau Molnar
--              Version 1.5 is finalized
--              Bug fix. In V1.4 and earlier table comparison failed if the tables that 
--              were compared had columns with names that contained spaces.
-- 08/15/2010 - Ladislau Molnar
--              Version 1.6 is finalized
--              Adding Setup and Teardown at the Test Session level. One can provide a stored procedure 
--              to be run at the beginning of each test session or another stored procedure to be run 
--              at the end of each test session.
--              Fix a bug: “Not well-formed xml result generated for some failed test cases”.
--              Add a new Assert API: Assert.IsTableNotEmpty.
-- 05/28/2011   Ladislau Molnar
--              Version 1.7 is finalized
--              Bug fix. In V1.6 and earlier a RAISERROR in a TRIGGER cannot be tested by 
--              registering an expected error.
-- 11/05/2011   Ladislau Molnar
--              Version 1.8 is finalized
--              Alow users to customize the prefix "SQLTest_".
--              Introduce Assert.Ignore.
--              Fix bug: A test session is reported as passing even when the test session setup or teardown failed.
--              Improve the text and Xml output when test session setup/teardown are present.
-- ==================================================================

/*
General comments
=====================================================================
SECTION 'Results Format'
Several stored procedures have a parameter named @ResultsFormat. This 
indicates the format in which the results are printed. The valid values are: 
   'Text'   - The results will be printed in plain text format. The output 
              contains a line showing the passed/failed status in the format:
                  TST Status: XXXX
              where XXXX is Passed or Failed.
   'XML'    - The results will be printed in an XML format. 
   'Batch'  - The same as 'Text' and additionally it prints the testSessionId
              in the format:
                  TST TestSessionId: X
              where X is the TestSessionId
   'None'   - Nothing will be printed
=====================================================================
*/

USE tempdb

-- =======================================================================
-- Creates the TST Database. If already exists then drops it first.
-- =======================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TST')
BEGIN
   DROP DATABASE TST
END

CREATE DATABASE TST
GO

USE TST
GO

-- =======================================================================
-- TST Schemas
-- =======================================================================

CREATE SCHEMA Assert
GO

CREATE SCHEMA Runner
GO

CREATE SCHEMA Utils
GO

CREATE SCHEMA Internal
GO

CREATE SCHEMA Data
GO

-- =======================================================================
-- START TST Tables and views.
-- =======================================================================

-- =======================================================================
-- TABLE: TSTVersion
-- This table will contain a signature and version information.
-- Note: The signature is used to make sure during the automated setup 
-- that if a TST database already exists is not an unrelated TST 
-- database that by chance has the same name.
-- =======================================================================
CREATE TABLE Data.TSTVersion(
   TSTSignature         varchar(100) NOT NULL,
   MajorVersion         int NOT NULL,
   MinorVersion         int NOT NULL,
   SetupDate            datetime NOT NULL DEFAULT(GETDATE())
)

-- Get the MajorVersion and MinorVersion from the caller (this script is invoked using SQLCMD)
DECLARE @TST_MajorVersion int
DECLARE @TST_MinorVersion int
SET @TST_MajorVersion = $(MajorVersion)
SET @TST_MinorVersion = $(MinorVersion)

INSERT INTO Data.TSTVersion(TSTSignature, MajorVersion, MinorVersion) VALUES ('TST-{6C57D85A-CE44-49ba-9286-A5227961DF02}', @TST_MajorVersion, @TST_MinorVersion)
GO

-- =======================================================================
-- TABLE: TSTVariables
-- This table will contain TST variables defined per test database.
-- =======================================================================
CREATE TABLE Data.TSTVariables(
   VariableId           int NOT NULL IDENTITY(1,1),   -- Identifies the variable.
   DatabaseName         sysname NULL,                 -- Identifies the database for which the variable is set.
                                                      -- If NULL then the variable is global.
   VariableName         varchar(32) NOT NULL,         -- Name of the variable.
   VariableValue        varchar(100) NOT NULL,        -- Value of the variable.
)

ALTER TABLE Data.TSTVariables ADD CONSTRAINT PK_TSTVariables PRIMARY KEY CLUSTERED (VariableId)

-- The same variable cannot be specified twice for the same database scope
ALTER TABLE Data.TSTVariables ADD CONSTRAINT UK_TSTVariables_DatabaseName_VariableName UNIQUE(DatabaseName, VariableName)

ALTER TABLE Data.TSTVariables ADD CONSTRAINT CK_TSTVariables_VariableName CHECK (
   VariableName = 'SqlTestPrefix'        -- Indicates the prefix used to identify the test procedures. See SFN_GetTestProcedurePrefix
)
GO

-- =======================================================================
-- TABLE: TSTParameters
-- This table will contain TST parameters per test session
-- They will direct different aspects of the test session.
-- Note: Transitory data. The row describing one test session will be 
--                        deleted after the test session is completed.
-- =======================================================================
CREATE TABLE Data.TSTParameters(
   ParameterId          int NOT NULL IDENTITY(1,1),   -- Identifies the parameter. 
   TestSessionId        int NOT NULL,                 -- Identifies the test session. 
   ParameterName        varchar(32) NOT NULL,         -- See CK_TSTParameters_ParameterName
   ParameterValue       varchar(100)NOT NULL,         -- The parameter value. Depends on the ParameterName. 
                                                      -- See CK_TSTParameters_ParameterName.
   Scope                sysname NOT NULL,             -- See CK_TSTParameters_Scope
   ScopeValue           sysname NULL,                 -- Depends on Scope. see CK_TSTParameters_Scope
)

ALTER TABLE Data.TSTParameters ADD CONSTRAINT PK_TSTParameters PRIMARY KEY CLUSTERED (ParameterId)

-- The same parameter cannot be specified twice in the same scope
ALTER TABLE Data.TSTParameters ADD CONSTRAINT UK_TSTParameters_TestSessionId_ParameterName_Scope_ScopeValue UNIQUE(TestSessionId, ParameterName, Scope, ScopeValue)

ALTER TABLE Data.TSTParameters ADD CONSTRAINT CK_TSTParameters_ParameterName CHECK (
   ParameterName = 'UseTSTRollback'       -- Indicates if the TST runners (the TST.Runner.RunXXX APIs) use transactions to rollback changes
                                          -- In this case the ParameterValue can be:
                                          --                     0 - Do NOT use transactions.
                                          --       any other value - Use transactions.
                                          -- If 'UseTSTRollback' is not specified the default value is '1'
)

ALTER TABLE Data.TSTParameters ADD CONSTRAINT CK_TSTParameters_Scope CHECK (
      Scope = 'All'        -- Indicates that the parameter applies to the entire test session.
                           -- In this case the ScopeValue is ignored
   OR Scope = 'Suite'      -- Indicates that the parameter applies during the scope of one suite.
                           -- In this case the ScopeValue is the name of the suite.
                           -- Parameters set in the suite scope overwrite ones set in the 'All' scope.
   OR Scope = 'Test'       -- Indicates that the parameter applies during the scope of one test.
                           -- In this case the ScopeValue is the name of the stored procedure 
                           -- that implements the test.
                           -- Parameters set in the test scope overwrite ones set in the 'All' and 'Suite' scope.
)

-- =======================================================================
-- TABLE: TestSession
-- This table will contain summary information about test sessions.
-- Note: Transitory data. The row describing one test session will be 
--                        deleted after the test session is completed.
-- =======================================================================
CREATE TABLE Data.TestSession(
   TestSessionId  int NOT NULL IDENTITY(1,1),   -- Identifies the test session. 
                                                -- Multiple clients can simultaneously execute their own test runs.
   DatabaseName         sysname NOT NULL,       -- Identifies the database that is the subject of the current run.
   TestSessionStart     datetime NOT NULL,      -- The time when the current run started.
   TestSessionFinish    datetime                -- The time when the current run finished.
                                                -- NULL while the run is in progress
)

ALTER TABLE Data.TestSession ADD CONSTRAINT PK_TestSession PRIMARY KEY CLUSTERED (TestSessionId)

GO

-- =======================================================================
-- Table: Suite
-- This table associates a suite name with a suite ID.
-- Note: Transitory data. The rows describing suites that are part of 
--                        a test session will be deleted after the test 
--                        session is completed.
-- =======================================================================
CREATE TABLE Data.Suite(
   SuiteId        int NOT NULL IDENTITY(1,1),
   TestSessionId  int NOT NULL,              -- Identifies the test session that this suite belongs to.
   SchemaName     sysname NULL,              -- NULL will be reserved for the Anonymous suite
                                             -- All tests that are not grouped to a suite are considered to belong to an anonymous suite. 
                                             -- That anonymous suite has an entry in this table where SchemaName and SuiteName are NULL.
   SuiteName      sysname NULL,              -- NULL will be reserved for the Anonymous suite.
                                             -- (see the comments on SchemaName).
)
   
ALTER TABLE Data.Suite ADD CONSTRAINT PK_Suite PRIMARY KEY CLUSTERED (SuiteId)
ALTER TABLE Data.Suite ADD CONSTRAINT UK_Suite_TestSessionId_SuiteName UNIQUE(TestSessionId, SchemaName, SuiteName)
ALTER TABLE Data.Suite ADD CONSTRAINT FK_Suite_TestSessionId FOREIGN KEY(TestSessionId) REFERENCES Data.TestSession(TestSessionId)
CREATE NONCLUSTERED INDEX IX_Suite_TestSessionId_SuiteId ON Data.Suite(TestSessionId, SuiteId)

GO

-- =======================================================================
-- TABLE: Test
-- This table stores information about every test that has to be run in 
-- the current test session.
-- Note: Transitory data. The rows describing tests that are part of 
--                        a test session will be deleted after the test 
--                        session is completed.
-- =======================================================================
CREATE TABLE Data.Test(
   TestId         int NOT NULL IDENTITY(1,1),   -- Identifies the test 
   TestSessionId  int NOT NULL,                 -- Identifies the test session that this test belongs to.
                                                -- Note: this is a denormalization. TestSessionId could have been determined
                                                -- having SuiteId known. TestSessionId is present here for convenience.
   SuiteId        int NOT NULL,                 -- Identifies the suite that this test belongs to.
   SchemaName     sysname NOT NULL,             -- The schema name of the procedures that implements the test (like 'dbo')
   SProcName      sysname NOT NULL,             -- The name of the procedures that implements the test
   SProcType      varchar(10) NOT NULL          -- Indicates the type of procedure and can be:
                                                --    'SetupS'
                                                --    'TeardownS'
                                                --    'Setup'
                                                --    'Teardown'
                                                --    'Test'
)
   
ALTER TABLE Data.Test ADD CONSTRAINT PK_Test PRIMARY KEY CLUSTERED (TestId)
ALTER TABLE Data.Test ADD CONSTRAINT UK_Test_SuiteId_SchemaName_SProcName UNIQUE(SuiteId, SchemaName, SProcName)
ALTER TABLE Data.Test ADD CONSTRAINT UK_Test_TestSessionId_SchemaName_SProcName UNIQUE(TestSessionId, SchemaName, SProcName)
ALTER TABLE Data.Test ADD CONSTRAINT CK_Test_SProcType CHECK  (SProcType = 'SetupS' OR SProcType = 'TeardownS' OR SProcType = 'Setup' OR SProcType = 'Teardown' OR SProcType = 'Test')
ALTER TABLE Data.Test ADD CONSTRAINT FK_Test_SuiteId FOREIGN KEY(SuiteId) REFERENCES Data.Suite(SuiteId)
CREATE NONCLUSTERED INDEX IX_Test_SuiteId_SProcName ON Data.Test(SuiteId, SProcName)
CREATE NONCLUSTERED INDEX IX_Test_TestSessionId_SProcName ON Data.Test(TestSessionId, SProcName)

GO

-- =======================================================================
-- TABLE: TestLog
-- This table collects all the log entries.
-- Note: Transitory data. The rows describing entries saved as part of 
--                        a test session will be deleted after the test 
--                        session is completed.
-- =======================================================================
CREATE TABLE Data.TestLog(
   LogEntryId    int NOT NULL IDENTITY(1,1),             -- Identifies the log entry
   TestSessionId int NOT NULL,                           -- Identifies the test session that this log entry belongs to. 
                                                         -- Note: there is a little denormalization here. TestSessionId 
                                                         -- is here for convinience. It could be determined based on TestId. 
   TestId        int NOT NULL,                           -- Identifies the test that this log entry belongs to.
   EntryType     char NOT NULL,                          -- Indicates the type of log entry:
                                                         --    'P' - Pass
                                                         --    'I' - Ignore
                                                         --    'L' - Log
                                                         --    'F' - Fail
                                                         --    'E' - Error
   CreatedTime   DateTime NOT NULL DEFAULT(GETDATE()),   -- The datetime when this entry was created.
   LogMessage    nvarchar(max) NOT NULL
)
   
ALTER TABLE Data.TestLog ADD CONSTRAINT PK_TestLog PRIMARY KEY CLUSTERED (LogEntryId)
ALTER TABLE Data.TestLog ADD CONSTRAINT FK_TestLog_TestSessionId FOREIGN KEY(TestSessionId) REFERENCES Data.TestSession(TestSessionId)
ALTER TABLE Data.TestLog ADD CONSTRAINT FK_TestLog_TestId FOREIGN KEY(TestId) REFERENCES Data.Test(TestId)
CREATE NONCLUSTERED INDEX IX_TestLog_TestSessionId ON Data.TestLog(TestSessionId)
CREATE NONCLUSTERED INDEX IX_TestLog_TestId ON Data.TestLog(TestId)
ALTER TABLE Data.TestLog ADD CONSTRAINT CK_TestLog_EntryType CHECK  (EntryType = 'P' OR EntryType = 'I' OR EntryType = 'L' OR EntryType = 'F' OR EntryType = 'E')

GO

-- =======================================================================
-- TABLE: SystemErrorLog
-- This table collects log entries regarding errors that occured outside 
-- of any test. Normally these logs corespond to issues that occured 
-- in the preparatory phase before any test is executed.
-- Note: Transitory data. The rows describing entries saved as part of 
--                        a test session will be deleted after the test 
--                        session is completed.
-- =======================================================================
CREATE TABLE Data.SystemErrorLog(
   LogEntryId    int NOT NULL IDENTITY(1,1),             -- Identifies the log entry
   TestSessionId int NOT NULL,                           -- Identifies the test session that this log entry belongs to. 
   CreatedTime   DateTime NOT NULL DEFAULT(GETDATE()),   -- The datetime when this entry was created.
   LogMessage    nvarchar(max) NOT NULL
)
   
ALTER TABLE Data.SystemErrorLog ADD CONSTRAINT PK_SystemErrorLog PRIMARY KEY CLUSTERED (LogEntryId)
ALTER TABLE Data.SystemErrorLog ADD CONSTRAINT FK_SystemErrorLog_TestSessionId FOREIGN KEY(TestSessionId) REFERENCES Data.TestSession(TestSessionId)
CREATE NONCLUSTERED INDEX IX_SystemErrorLog_TestSessionId ON Data.SystemErrorLog(TestSessionId)

GO

-- =======================================================================
-- VIEW: TSTResults 
-- Aggregates data from several tables to facilitate results reporting
-- =======================================================================
CREATE VIEW Data.TSTResults AS
SELECT 
   TestLog.LogEntryId,
   TestLog.TestSessionId,
   Suite.SuiteId,
   Suite.SuiteName,
   Test.TestId,
   Test.SProcName,
   Test.SProcType,
   TestLog.EntryType,
   TestLog.CreatedTime,
   TestLog.LogMessage
FROM Data.TestLog
INNER JOIN Data.Test  ON TestLog.TestId = Test.TestId
INNER JOIN Data.Suite ON Suite.SuiteId = Test.SuiteId

GO

-- =======================================================================
-- VIEW: TSTResultsEx
-- Aggregates data from several tables to facilitate results reporting
-- Adds more info compared with TSTResults. Specifically test status and suite status
-- =======================================================================
CREATE VIEW Data.TSTResultsEx AS
SELECT 
   LogEntries.LogEntryId,
   LogEntries.TestSessionId,
   Suite.SuiteId,
   ISNULL(Suite.SuiteName, 'Anonymous') AS SuiteName,
   SuiteStatus = CASE WHEN SuiteFailInfo.FailuresOrErrorsCount > 0 THEN 'F' ELSE 'P' END,
   Test.TestId,
   Test.SProcName,
   TestStatus = CASE WHEN TestFailInfo.FailuresOrErrorsCount > 0 THEN 'F' ELSE 'P' END,
   LogEntries.EntryType,
   LogEntries.LogMessage,
   LogEntries.CreatedTime
FROM Data.TestLog AS LogEntries
INNER JOIN Data.Test  ON LogEntries.TestId = Test.TestId
INNER JOIN Data.Suite ON Suite.SuiteId = Test.SuiteId
INNER JOIN  (  SELECT 
                  TestId, 
                  (  SELECT COUNT(*) FROM Data.TestLog AS L1
                     WHERE 
                        (L1.EntryType = 'E' OR L1.EntryType = 'F' )
                        AND L1.TestId = T1.TestId
                  ) AS FailuresOrErrorsCount
               FROM TST.Data.Test AS T1
            ) AS TestFailInfo ON TestFailInfo.TestId = Test.TestId

INNER JOIN  (  SELECT 
                  SuiteId, 
                  (  SELECT COUNT(*) FROM Data.TestLog L2
                     INNER JOIN Data.Test AS T2 ON L2.TestId = T2.TestId 
                     WHERE 
                        (L2.EntryType = 'E' OR L2.EntryType = 'F' )
                        AND T2.SuiteId = S1.SuiteId
                  ) AS FailuresOrErrorsCount
               FROM TST.Data.Suite AS S1
            ) AS SuiteFailInfo ON SuiteFailInfo.SuiteId = Suite.SuiteId

GO

-- =======================================================================
-- END TST Tables and views.
-- =======================================================================

-- =======================================================================
-- START TST Internals.
-- These are functions and stored procedures internal to the TST framework.
-- =======================================================================

-- Early declaration. This sproc is declared to avoid a warning (Cannot add rows to sys.sql_dependencies ...)
-- It will be properly defined later.
CREATE PROCEDURE Assert.Pass
   @Message nvarchar(max) = ''
AS
BEGIN
   RAISERROR ('Early declaration of Assert.Pass', 16, 1)
END
GO

-- Early declaration. This sproc is declared to avoid a warning (Cannot add rows to sys.sql_dependencies ...)
-- It will be properly defined later.
CREATE PROCEDURE Assert.Fail 
   @ErrorMessage  nvarchar(max)
AS
BEGIN
   RAISERROR ('Early declaration of Assert.Fail', 16, 1)
END
GO

-- Early declaration. This sproc is declared to avoid a warning (Cannot add rows to sys.sql_dependencies ...)
-- It will be properly defined later.
CREATE PROCEDURE Internal.ClearExpectedError
AS 
BEGIN
   RAISERROR ('Early declaration of Internal.ClearExpectedError', 16, 1)
END
GO


-- =======================================================================
-- FUNCTION SFN_GetListToTable
-- Takes a list with items separated by semicolons and returns a table 
-- where each row contains one item. Each item is max 500 characters otherwise 
-- a truncation error occurs.
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetListToTable(@List varchar(max)) 
RETURNS @ListToTable TABLE (ListItem varchar(500) )
AS 
BEGIN

   IF (@List IS NULL) RETURN

   DECLARE @IndexStart  int
   DECLARE @IndexEnd    int
   DECLARE @CrtItem     varchar(500)
   
   SET @IndexStart = 1;
   WHILE (@IndexStart <= DATALENGTH(@List) + 1)
   BEGIN
      SET @IndexEnd = CHARINDEX(';', @List, @IndexStart)
      IF (@IndexEnd = 0) SET @IndexEnd = DATALENGTH(@List) + 1
      IF (@IndexEnd > @IndexStart)
      BEGIN
         SET @CrtItem = SUBSTRING(@List, @IndexStart, @IndexEnd - @IndexStart)
         INSERT INTO @ListToTable(ListItem) VALUES (@CrtItem)
      END
      
      SET @IndexStart = @IndexEnd + 1
   END

   RETURN
END
GO


-- =======================================================================
-- FUNCTION SFN_EscapeForXml
-- Returns the given string after escaping characters that have a special 
-- role in an XML file.
-- =======================================================================
CREATE FUNCTION Internal.SFN_EscapeForXml(@TextString nvarchar(max)) RETURNS nvarchar(max)
AS
BEGIN

   SET @TextString = REPLACE (@TextString, '"', '&quot;')
   SET @TextString = REPLACE (@TextString, '&', '&amp;')
   SET @TextString = REPLACE (@TextString, '>', '&gt;')
   SET @TextString = REPLACE (@TextString, '<', '&lt;')

   RETURN @TextString 
   
END
GO


-- =======================================================================
-- FUNCTION SFN_GetEntryTypeName
-- Returns the name corresponding to the @EntryType. See TestLog.EntryType
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetEntryTypeName(@EntryType char) RETURNS varchar(10)
AS
BEGIN

   IF @EntryType = 'P' RETURN 'Pass'
   IF @EntryType = 'I' RETURN 'Ignore'
   IF @EntryType = 'L' RETURN 'Log'
   IF @EntryType = 'F' RETURN 'Failure'
   IF @EntryType = 'E' RETURN 'Error'

   RETURN '???'
   
END
GO

-- =======================================================================
-- FUNCTION SFN_GetFullSprocName
-- Returns the full name of the sproc identified by @TestId
-- The full name has the format: Database.Schema.Name
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetFullSprocName(@TestId int) RETURNS nvarchar(1000)
AS
BEGIN

   DECLARE @DatabaseName   sysname
   DECLARE @SchemaName     sysname
   DECLARE @SProcName      sysname
   DECLARE @FullSprocName  nvarchar(1000)

   SELECT 
      @DatabaseName  = TestSession.DatabaseName,
      @SchemaName    = Test.SchemaName,
      @SProcName     = Test.SProcName
   FROM Data.Test
   INNER JOIN Data.TestSession ON TestSession.TestSessionId = Test.TestSessionId
   WHERE TestId = @TestId
   
   SET @FullSprocName = QUOTENAME(@DatabaseName) + '.' + QUOTENAME(ISNULL(@SchemaName, '')) + '.' + QUOTENAME(@SProcName)

   RETURN @FullSprocName
   
END
GO

-- =======================================================================
-- PROCEDURE SuiteExists
-- Determines if the suite with the name given by @TestName exists 
-- in the database with the name given by @TestDatabaseName.
-- =======================================================================
CREATE PROCEDURE Internal.SuiteExists
   @TestDatabaseName       sysname, 
   @SuiteName              sysname,
   @TestProcedurePrefix    varchar(100),
   @SuiteExists            bit OUT 
AS
BEGIN

   DECLARE @SqlCommand        nvarchar(1000)
   DECLARE @Params            nvarchar(100)
   DECLARE @TestInSuiteCount  int

   SET @SqlCommand = 'SELECT @TestInSuiteCountOUT = COUNT(*) ' + 
      'FROM ' + QUOTENAME(@TestDatabaseName) + '.sys.procedures ' + 
      'WHERE name LIKE ''' + @TestProcedurePrefix + @SuiteName + '#%'''

   SET @Params = '@TestInSuiteCountOUT int OUT'
   EXEC sp_executesql @SqlCommand, @Params, @TestInSuiteCountOUT=@TestInSuiteCount OUT

   SET @SuiteExists = 0
   IF (@TestInSuiteCount >= 1) SET @SuiteExists = 1

END
GO


-- =======================================================================
-- FUNCTION SFN_SProcExists
-- Determines if the procedure with the name given by @TestName exists 
-- in database with the name given by @TestDatabaseName.
-- =======================================================================
CREATE FUNCTION Internal.SFN_SProcExists(@TestDatabaseName sysname, @SProcNameName sysname) RETURNS bit
AS
BEGIN

   DECLARE @ObjectName nvarchar(1000)
   SET @ObjectName = @TestDatabaseName + '..' + @SProcNameName

   IF (object_id(@ObjectName, 'P') IS NOT NULL)
   BEGIN
      RETURN 1
   END

   RETURN 0
END
GO


-- =======================================================================
-- FUNCTION SFN_UseTSTRollbackForTest
-- Determins if transactions can be used for the given test.
-- =======================================================================
CREATE FUNCTION Internal.SFN_UseTSTRollbackForTest(@TestSessionId int, @TestId int) RETURNS bit
AS
BEGIN

   DECLARE @UseTSTRollback varchar(100)
   
   SET @UseTSTRollback = '1' -- Default value

   SELECT @UseTSTRollback = TSTParameters.ParameterValue
   FROM Data.TSTParameters 
   WHERE 
      TestSessionId = @TestSessionId
      AND ParameterName  = 'UseTSTRollback'
      AND Scope = 'All'

   -- The 'Suite' scope will overwrite the 'All' scope
   SELECT @UseTSTRollback = TSTParameters.ParameterValue
   FROM Data.TSTParameters
   INNER JOIN Data.Suite ON 
      Suite.TestSessionId = TSTParameters.TestSessionId
      AND TSTParameters.Scope = 'Suite'
      AND Suite.SuiteName = TSTParameters.ScopeValue
   INNER JOIN Data.Test ON 
      Test.SuiteId = Suite.SuiteId
   WHERE 
      TSTParameters.TestSessionId = @TestSessionId
      AND TSTParameters.ParameterName  = 'UseTSTRollback'
      AND Test.TestId = @TestId

   -- The 'Test' scope will overwrite the 'Suite' and 'All' scope
   SELECT @UseTSTRollback = TSTParameters.ParameterValue
   FROM Data.TSTParameters
   INNER JOIN Data.Test ON 
      Test.TestSessionId = TSTParameters.TestSessionId
      AND TSTParameters.Scope = 'Test'
      AND Test.SProcName = TSTParameters.ScopeValue
   WHERE 
      TSTParameters.TestSessionId = @TestSessionId
      AND TSTParameters.ParameterName  = 'UseTSTRollback'
      AND Test.TestId = @TestId
      
   IF @UseTSTRollback = '0' RETURN 0
   RETURN 1
   
END
GO

-- =======================================================================
-- FUNCTION: SFN_GetCountOfPassEntriesForTest
-- Returns the number of log entries indicating pass for the given test.
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetCountOfPassEntriesForTest(@TestId int) RETURNS int
AS 
BEGIN

   DECLARE @PassEntries int

   SELECT @PassEntries = COUNT(1) 
   FROM Data.TestLog 
   WHERE 
      TestLog.TestId = @TestId
      AND EntryType = 'P'

   RETURN ISNULL(@PassEntries, 0)

END
GO

-- =======================================================================
-- FUNCTION: SFN_GetCountOfFailOrErrorEntriesForTest
-- Returns the number of log entries indicating failures or 
-- errors for the given test.
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetCountOfFailOrErrorEntriesForTest(@TestId int) RETURNS int
AS 
BEGIN

   DECLARE @FailOrErrorEntries int

   SELECT @FailOrErrorEntries = COUNT(1) 
   FROM Data.TestLog 
   WHERE 
      TestLog.TestId = @TestId
      AND EntryType IN ('F', 'E')

   RETURN ISNULL(@FailOrErrorEntries, 0)

END
GO

-- =======================================================================
-- FUNCTION: SFN_GetCountOfIgnoreEntriesForTest
-- Returns the number of log entries indicating 'Ignore' for the given test.
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetCountOfIgnoreEntriesForTest(@TestId int) RETURNS int
AS 
BEGIN

   DECLARE @IgnoreEntries int

   SELECT @IgnoreEntries = COUNT(1) 
   FROM Data.TestLog 
   WHERE 
      TestLog.TestId = @TestId
      AND EntryType = 'I'

   RETURN ISNULL(@IgnoreEntries, 0)

END
GO

-- =======================================================================
-- FUNCTION SFN_GetCountOfSuitesInSession
-- Returns the number of suites in the given session
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetCountOfSuitesInSession(@TestSessionId int) RETURNS int
AS
BEGIN
   DECLARE @CountOfSuitesInSession int

   SELECT @CountOfSuitesInSession = COUNT(1) 
   FROM Data.Suite WHERE TestSessionId = @TestSessionId AND ISNULL(SuiteName, 'Anonymous') != '#SessionSetup#' AND ISNULL(SuiteName, 'Anonymous') != '#SessionTeardown#'

   RETURN ISNULL(@CountOfSuitesInSession, 0)
END
GO

-- =======================================================================
-- FUNCTION SFN_GetCountOfTestsInSession
-- Returns the number of tests in the given session
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetCountOfTestsInSession(@TestSessionId int) RETURNS int
AS
BEGIN

   DECLARE @CountOfTestsInSession int
   
   SELECT @CountOfTestsInSession = COUNT(1) 
   FROM Data.Test 
   WHERE 
      Test.TestSessionId = @TestSessionId
      AND Test.SProcType = 'Test'
   
   RETURN ISNULL(@CountOfTestsInSession, 0)
END
GO

-- =======================================================================
-- FUNCTION SFN_GetCountOfPassedTestsInSession
-- Returns the number of tests that have passed in the given session
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetCountOfPassedTestsInSession(@TestSessionId int) RETURNS int
AS
BEGIN

   DECLARE @CountOfPassedTestsInSession int

   SELECT @CountOfPassedTestsInSession = COUNT(1) 
   FROM Data.Test 
   WHERE 
      Test.TestSessionId = @TestSessionId
      AND Test.SProcType = 'Test'
      AND Internal.SFN_GetCountOfPassEntriesForTest(Test.TestId) >= 1
      AND Internal.SFN_GetCountOfIgnoreEntriesForTest(Test.TestId) = 0
      AND Internal.SFN_GetCountOfFailOrErrorEntriesForTest(Test.TestId) = 0

   RETURN ISNULL(@CountOfPassedTestsInSession, 0)

END
GO

-- =======================================================================
-- FUNCTION SFN_GetCountOfIgnoredTestsInSession
-- Returns the number of tests that have passed in the given session
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetCountOfIgnoredTestsInSession(@TestSessionId int) RETURNS int
AS
BEGIN

   DECLARE @CountOfIgnoredTestsInSession int
   
   SELECT @CountOfIgnoredTestsInSession = COUNT(1) 
   FROM Data.Test 
   WHERE 
      Test.TestSessionId = @TestSessionId
      AND Test.SProcType = 'Test'
      AND Internal.SFN_GetCountOfIgnoreEntriesForTest(Test.TestId) >= 1
      AND Internal.SFN_GetCountOfFailOrErrorEntriesForTest(Test.TestId) = 0

   RETURN ISNULL(@CountOfIgnoredTestsInSession, 0)

END
GO

-- =======================================================================
-- FUNCTION SFN_GetCountOfFailedTestsInSession
-- Returns the number of failed tests in the given test session
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetCountOfFailedTestsInSession(@TestSessionId int) RETURNS int
AS
BEGIN
   
   DECLARE @CountOfFailedTestsInSession int
   
   SELECT @CountOfFailedTestsInSession = COUNT(1) 
   FROM (
         SELECT DISTINCT Test.TestId 
         FROM Data.TestLog 
         INNER JOIN Data.Test ON Test.TestId = TestLog.TestId
         WHERE 
            TestLog.TestSessionId = @TestSessionId
            AND TestLog.EntryType IN ('F', 'E')
            AND Test.SProcType = 'Test'
        ) AS FailedTestsList
   
   RETURN ISNULL(@CountOfFailedTestsInSession, 0)
   
END
GO

-- =======================================================================
-- FUNCTION SFN_SystemErrorsExistInSession
-- Returns a flag indicating if any system errors exist 
-- in the given test session.
-- =======================================================================
CREATE FUNCTION Internal.SFN_SystemErrorsExistInSession(@TestSessionId int) RETURNS int
AS
BEGIN

   IF EXISTS (SELECT * FROM Data.SystemErrorLog WHERE TestSessionId = @TestSessionId)
   BEGIN
      RETURN 1
   END

   RETURN 0
   
END
GO

-- =======================================================================
-- FUNCTION SFN_GetSessionStatus
-- Returns a flag indicating if the test session passed or failed.
--    1 - The test session passed.
--    0 - The test session failed.
-- in the given test session.
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetSessionStatus(@TestSessionId int) RETURNS int
AS
BEGIN

   DECLARE @ErrorOrFailuresExistInSession    bit
   DECLARE @SystemErrorsExistInSession       bit
   
   SET @ErrorOrFailuresExistInSession = Internal.SFN_ErrorOrFailuresExistInSession(@TestSessionId) 
   SET @SystemErrorsExistInSession = Internal.SFN_SystemErrorsExistInSession(@TestSessionId) 
   
   IF (@ErrorOrFailuresExistInSession = 1 OR @SystemErrorsExistInSession = 1) RETURN 0
   RETURN 1

END
GO

-- =======================================================================
-- FUNCTION SFN_ErrorOrFailuresExistInSession
-- Returns a flag indicating if any errors or failures exist 
-- in the given test session.
-- =======================================================================
CREATE FUNCTION Internal.SFN_ErrorOrFailuresExistInSession(@TestSessionId int) RETURNS int
AS
BEGIN

   IF EXISTS (SELECT * FROM Data.TestLog WHERE TestLog.TestSessionId = @TestSessionId AND TestLog.EntryType IN ('F', 'E'))
   BEGIN
      RETURN 1
   END

   RETURN 0

END
GO

-- =======================================================================
-- FUNCTION SFN_GetSuiteTypeId
-- Returns an ID that can be used to order suites based on their type:
--    0: Session Setup suite.
--    1: The anonymous suite.
--    2: A regular suite.
--    3: Session Setup teardown.
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetSuiteTypeId(@SuiteName sysname) RETURNS int
AS
BEGIN

   IF (@SuiteName = '#SessionSetup#') RETURN 0
   IF (@SuiteName = '#SessionTeardown#') RETURN 3
   ELSE IF (@SuiteName IS NULL ) RETURN 1

   RETURN 2

END
GO

-- =======================================================================
-- FUNCTION SFN_GetCountOfTestsInSuite
-- Returns the number of passed tests in the given suite
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetCountOfTestsInSuite(@SuiteId int) RETURNS int
AS
BEGIN
   
   DECLARE @CountOfTestInSuite int
   
   SELECT @CountOfTestInSuite = COUNT(1) 
   FROM Data.Test 
   WHERE 
      Test.SuiteId = @SuiteId
      AND Test.SProcType = 'Test'

   
   RETURN ISNULL(@CountOfTestInSuite, 0)
   
END
GO

-- =======================================================================
-- FUNCTION SFN_GetCountOfFailedTestsInSuite
-- Returns the number of failed tests in the given suite
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetCountOfFailedTestsInSuite(@SuiteId int) RETURNS int
AS
BEGIN
   
   DECLARE @CountOfFailedTestInSuite int
   
   SELECT @CountOfFailedTestInSuite = COUNT(1) 
   FROM (
         SELECT DISTINCT Test.TestId 
         FROM Data.TestLog 
         INNER JOIN Data.Test ON TestLog.TestId = Test.TestId
         WHERE 
            Test.SuiteId = @SuiteId
            AND TestLog.EntryType IN ('F', 'E')
            AND Test.SProcType = 'Test'
        ) AS FailedTestsList
   
   RETURN ISNULL(@CountOfFailedTestInSuite, 0)
   
END
GO


-- =======================================================================
-- FUNCTION SFN_GetCountOfIgnoredTestsInSuite
-- Returns the number of ignored tests in the given suite
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetCountOfIgnoredTestsInSuite(@SuiteId int) RETURNS int
AS
BEGIN

   DECLARE @CountOfIgnoredTestInSuite int

   SELECT @CountOfIgnoredTestInSuite = COUNT(1) 
   FROM Data.Test 
   WHERE 
      Test.SuiteId = @SuiteId
      AND Test.SProcType = 'Test'
      AND Internal.SFN_GetCountOfIgnoreEntriesForTest(Test.TestId) >= 1
      AND Internal.SFN_GetCountOfFailOrErrorEntriesForTest(Test.TestId) = 0

   RETURN ISNULL(@CountOfIgnoredTestInSuite, 0)
   
END
GO

-- =======================================================================
-- FUNCTION SFN_GetCountOfPassedTestsInSuite
-- Returns the number of passed tests in the given suite
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetCountOfPassedTestsInSuite(@SuiteId int) RETURNS int
AS
BEGIN

   DECLARE @CountOfPassedTestInSuite int

   SELECT @CountOfPassedTestInSuite = COUNT(1) 
   FROM Data.Test 
   WHERE 
      Test.SuiteId = @SuiteId
      AND Test.SProcType = 'Test'
      AND Internal.SFN_GetCountOfPassEntriesForTest(Test.TestId) >= 1
      AND Internal.SFN_GetCountOfIgnoreEntriesForTest(Test.TestId) = 0
      AND Internal.SFN_GetCountOfFailOrErrorEntriesForTest(Test.TestId) = 0

   RETURN ISNULL(@CountOfPassedTestInSuite, 0)
   
END
GO

-- =======================================================================
-- PROCEDURE GetCurrentTestSessionId
-- Returns in @TestSessionId the test session id for the current
-- test session.
-- =======================================================================
CREATE PROCEDURE Internal.GetCurrentTestSessionId
   @TestSessionId int OUT
AS
BEGIN

   SELECT @TestSessionId = TestSessionId FROM #Tmp_CrtSessionInfo
   
END
GO

-- =======================================================================
-- PROCEDURE: LogErrorMessage
-- Called by some other TST infrastructure procedures to log an 
-- error message.
-- =======================================================================
CREATE PROCEDURE Internal.LogErrorMessage
   @ErrorMessage  nvarchar(max)
AS
BEGIN
   DECLARE @TestSessionId int
   DECLARE @TestId int
   
   SELECT @TestSessionId = TestSessionId, @TestId = TestId FROM #Tmp_CrtSessionInfo
   IF @TestId >= 0
   BEGIN
      INSERT INTO Data.TestLog(TestSessionId, TestId, EntryType, LogMessage) VALUES(@TestSessionId, @TestId, 'E', @ErrorMessage)
   END
   ELSE
   BEGIN
      INSERT INTO Data.SystemErrorLog(TestSessionId, LogMessage) VALUES(@TestSessionId, @ErrorMessage)
   END

END
GO

-- =======================================================================
-- PROCEDURE: LogInfoMessage
-- Called by some other TST infrastructure procedures to log an 
-- informational message.
-- =======================================================================
CREATE PROCEDURE Internal.LogInfoMessage
   @Message  nvarchar(max)
AS
BEGIN
   DECLARE @TestSessionId int
   DECLARE @TestId int

   SELECT @TestSessionId = TestSessionId, @TestId = TestId FROM #Tmp_CrtSessionInfo
   INSERT INTO Data.TestLog(TestSessionId, TestId, EntryType, LogMessage) VALUES(@TestSessionId, @TestId, 'L', ISNULL(@Message, ''))
END
GO


-- =======================================================================
-- PROCEDURE: LogErrorMessageAndRaiseError
-- Called by some other TST infrastructure procedures to log an 
-- error message and raise a TST error.
-- =======================================================================
CREATE PROCEDURE Internal.LogErrorMessageAndRaiseError
   @ErrorMessage  nvarchar(max)
AS
BEGIN
   EXEC Internal.LogErrorMessage @ErrorMessage
   RAISERROR('TST RAISERROR {6C57D85A-CE44-49ba-9286-A5227961DF02}', 16, 110)
END
GO

-- =======================================================================
-- PROCEDURE EnsureSuite
-- This will make sure that the given suite is recorded in the table Suite
-- It will return the Suite Id in @SuiteId
-- =======================================================================
CREATE PROCEDURE Internal.EnsureSuite
   @TestSessionId    int,              -- Identifies the test session.
   @SchemaName       sysname,          -- The schema name 
   @SuiteName        sysname,          -- The suite name
   @SuiteId          int OUTPUT        -- At return will indicate 
AS
BEGIN

   -- If this is the anonymous suite we'll ignore which schema is in. 
   IF @SuiteName IS NULL SET @SchemaName = NULL

   SET @SuiteId = NULL
   SELECT @SuiteId = SuiteId FROM Data.Suite 
   WHERE 
      @TestSessionId = TestSessionId 
      AND (SchemaName = @SchemaName OR (SchemaName IS NULL AND @SchemaName IS NULL) )
      AND (SuiteName = @SuiteName OR (SuiteName IS NULL AND @SuiteName IS NULL) )
   IF(@SuiteId IS NOT NULL) RETURN 0

   INSERT INTO Data.Suite(TestSessionId, SchemaName, SuiteName) VALUES(@TestSessionId, @SchemaName, @SuiteName)
   SET @SuiteId = SCOPE_IDENTITY()
   
   RETURN 0

END
GO

-- =======================================================================
-- PROCEDURE AnalyzeSprocName
-- Analyses the given stored procedure. Detects if it is TST procedure
-- and returns to the caller info needed to categorize it.
-- =======================================================================
CREATE PROCEDURE Internal.AnalyzeSprocName
   @SProcName              sysname,             -- The name of the stored procedure.
   @TestProcedurePrefix    varchar(100),        -- The prefix used to identify the test stored procedures
   @SuiteName              sysname OUTPUT,      -- At return it will be the suite name.
   @IsTSTSproc             bit OUTPUT,          -- At return it will indicate if it is a TST procedure.
   @SProcType              varchar(10) OUTPUT   -- At return it will indicate the type of TST procedure.
                                          -- See Data.Test.SProcType
AS
BEGIN

   DECLARE @TestNameIndex int

   SET @IsTSTSproc  = 0

   IF( CHARINDEX(@TestProcedurePrefix, @SProcName) != 1)   
   BEGIN
      -- This is not a SQL Test sproc
      RETURN 0
   END

   SET @IsTSTSproc = 1
   
   -- Remove the prefix from @SProcName.
   SET @SProcName = RIGHT(@SProcName, LEN(@SProcName) - LEN(@TestProcedurePrefix))
   
   IF( CHARINDEX('SETUP_', @SProcName) = 1)
   BEGIN
      SET @SProcType = 'Setup'
      SET @SuiteName = RIGHT(@SProcName, LEN(@SProcName) - 6)
      RETURN 0
   END
   
   IF( CHARINDEX('TEARDOWN_', @SProcName) = 1)
   BEGIN
      SET @SProcType = 'Teardown'
      SET @SuiteName = RIGHT(@SProcName, LEN(@SProcName) - 9)
      RETURN 0
   END
   
   SET @TestNameIndex = CHARINDEX('#', @SProcName)
   IF( @TestNameIndex != 0)
   BEGIN
      SET @SProcType = 'Test'
      SET @SuiteName = LEFT(@SProcName, @TestNameIndex - 1)
      RETURN 0
   END

   -- This test is not associated with a specific suite.
   SET @SuiteName = NULL
   SET @SProcType = 'Test'

   RETURN 0
   
END
GO

-- =======================================================================
-- PROCEDURE PrepareTestSessionSetupInformation 
-- Analyses the given database and prepares the information needed 
-- relating to the test session setup procedure.
-- Return code:
--    0 - OK. No test session setup procedure was found or one test session setup procedure was found.
--    1 - An error was detected. For example there are two test session setup procedures in different schemas.
-- =======================================================================
CREATE PROCEDURE Internal.PrepareTestSessionSetupInformation
   @TestSessionId          int,              -- Identifies the test session.
   @TestProcedurePrefix    varchar(100)      -- The prefix used to identify the test stored procedures
AS
BEGIN

   DECLARE @SuiteId                          int
   DECLARE @TestSessionSetupProceduresCount  int
   DECLARE @SchemaName                       sysname
   DECLARE @SessionSetupProcedureName        sysname

   SET @SessionSetupProcedureName = @TestProcedurePrefix + 'SESSION_SETUP'

   SELECT @TestSessionSetupProceduresCount = COUNT(*) FROM #Tmp_Procedures WHERE SProcName = @SessionSetupProcedureName
   IF(@TestSessionSetupProceduresCount = 0) RETURN 0
   IF(@TestSessionSetupProceduresCount > 1)
   BEGIN
      DECLARE @ErrorMessage varchar(1000)
      SET @ErrorMessage = 'You cannot define more than one test session setup procedures [' + @SessionSetupProcedureName + '].'
      EXEC Internal.LogErrorMessage @ErrorMessage
      RETURN 1
   END

   SELECT @SchemaName = SchemaName FROM #Tmp_Procedures WHERE SProcName = @SessionSetupProcedureName

   EXEC Internal.EnsureSuite @TestSessionId, @SchemaName, '#SessionSetup#', @SuiteId OUTPUT
   INSERT INTO Data.Test(TestSessionId, SuiteId, SchemaName, SProcName, SProcType) VALUES (@TestSessionId, @SuiteId, @SchemaName, @SessionSetupProcedureName, 'SetupS')

   RETURN 0

END
GO

-- =======================================================================
-- PROCEDURE PrepareTestSessionTeardownInformation
-- Analyses the given database and prepares the information needed 
-- relating to the test session teardown procedure.
-- Return code:
--    0 - OK. No test session teardown procedure was found or one test session teardown procedure was found.
--    1 - An error was detected. For example there are two test session teardown procedures in different schemas.
-- =======================================================================
CREATE PROCEDURE Internal.PrepareTestSessionTeardownInformation
   @TestSessionId          int,           -- Identifies the test session.
   @TestProcedurePrefix    varchar(100)   -- The prefix used to identify the test stored procedures
AS
BEGIN

   DECLARE @SuiteId                                int
   DECLARE @TestSessionTeardownProceduresCount     int
   DECLARE @SchemaName                             sysname
   DECLARE @SessionTeardownProcedureName           sysname

   SET @SessionTeardownProcedureName = @TestProcedurePrefix + 'SESSION_TEARDOWN'

   SELECT @TestSessionTeardownProceduresCount = COUNT(*) FROM #Tmp_Procedures WHERE SProcName = @SessionTeardownProcedureName
   IF(@TestSessionTeardownProceduresCount = 0) RETURN 0
   IF(@TestSessionTeardownProceduresCount > 1)
   BEGIN
      DECLARE @ErrorMessage varchar(1000)
      SET @ErrorMessage = 'You cannot define more than one test session teardown procedures [' + @SessionTeardownProcedureName + '].'
      EXEC Internal.LogErrorMessage @ErrorMessage
      RETURN 1
   END

   SELECT @SchemaName = SchemaName FROM #Tmp_Procedures WHERE SProcName = @SessionTeardownProcedureName

   EXEC Internal.EnsureSuite @TestSessionId, @SchemaName, '#SessionTeardown#', @SuiteId OUTPUT
   INSERT INTO Data.Test(TestSessionId, SuiteId, SchemaName, SProcName, SProcType) VALUES (@TestSessionId, @SuiteId, @SchemaName, @SessionTeardownProcedureName, 'TeardownS')

   RETURN 0

END
GO

-- =======================================================================
-- PROCEDURE PrepareTestSessionInformation
-- Analyses the given database and prepares all the information needed 
-- to run a test session in the given database.
-- Basically it detects all the TST test procedures for the given 
-- @TestDatabaseName, @TargetSuiteName and @TargetTestName.
-- Return code:
--    0 - OK
--    1 - An error was detected. For example:
--        The database given by @TestDatabaseName was not found or
--        @TargetSuiteName was specified and the suite given by @TargetSuiteName was not found or
--        @TargetTestName was specified and the test given by @TargetTestName was not found or
--        @TargetTestName was specified and the test name does not follow naming conventions for a TST test procedure.
--        No tests were detected that match the input parameters.
--        In case of an error an error message is stored in one of the log tables.
-- Note: This sproc will raise an error if the parameters are invalid in 
--       a way that indicates an internal error.
-- =======================================================================
CREATE PROCEDURE Internal.PrepareTestSessionInformation
   @TestSessionId          int,              -- Identifies the test session.
   @TestProcedurePrefix    varchar(100),     -- The prefix used to identify the test stored procedures
   @TestDatabaseName       sysname,          -- Specifies the database where the suite analysis is done.
   @TargetSuiteName        sysname,          -- The target suite name. It can be NULL and then all suites are candidates.
   @TargetTestName         sysname           -- The target test name. It can be NULL and then all tests are candidates.
AS
BEGIN

   DECLARE @ErrorMessage         nvarchar(1000)
   DECLARE @SqlCommand           nvarchar(1000)
   DECLARE @SuiteName            sysname
   DECLARE @IsTSTSproc           bit
   DECLARE @SProcType            varchar(10)
   DECLARE @SchemaName           sysname
   DECLARE @SProcName            sysname
   DECLARE @SuiteId              int
   DECLARE @DuplicateSuiteName   sysname
   DECLARE @DuplicateTestName    sysname
   DECLARE @ResultCode           int

   CREATE TABLE #Tmp_Procedures (
      SchemaName sysname NULL,
      SProcName sysname NOT NULL
   )
      
   IF (@TestDatabaseName IS NULL) 
   BEGIN
      RAISERROR('TST Internal Error. Invalid call to PrepareTestSessionInformation. @TestDatabaseName must be specified.', 16, 1)
      RETURN 1
   END

   IF (@TargetSuiteName IS NOT NULL AND @TargetTestName IS NOT NULL) 
   BEGIN
      RAISERROR('TST Internal Error. Invalid call to PrepareTestSessionInformation. @TargetSuiteName and @TargetTestName cannot both be specified.', 16, 1)
      RETURN 1
   END

   -- @TestDatabaseName must exist
   IF NOT EXISTS (SELECT [name] FROM sys.databases WHERE [name] = @TestDatabaseName)
   BEGIN
      SET @ErrorMessage = 'Database ''' + @TestDatabaseName + ''' not found.'
      EXEC Internal.LogErrorMessage @ErrorMessage
      RETURN 1
   END

   SELECT @SqlCommand = 
      'INSERT INTO #Tmp_Procedures ' + 
      'SELECT Schemas.name AS SchemaName, Procedures.name AS SProcName ' + 
      'FROM ' + QUOTENAME(@TestDatabaseName) + '.sys.procedures AS Procedures ' + 
      'INNER JOIN ' + QUOTENAME(@TestDatabaseName) + '.sys.schemas AS Schemas ON Schemas.schema_id = Procedures.schema_id ' + 
      'WHERE is_ms_shipped = 0 ORDER BY Procedures.name'

   EXEC (@SqlCommand)

   -- If @TargetTestName is specified then it must follow the TST naming conventions for a test name.
   -- At this point we must also determine its suite name so that the following loop can isolate its SETUP and TEARDOWN.
   IF @TargetTestName IS NOT NULL
   BEGIN
      EXEC Internal.AnalyzeSprocName @TargetTestName, @TestProcedurePrefix, @TargetSuiteName OUTPUT, @IsTSTSproc OUTPUT, @SProcType OUTPUT
      IF (@IsTSTSproc = 0 OR @SProcType != 'Test')
      BEGIN
         SET @ErrorMessage = 'Test procedure''' + @TargetTestName + ''' does not follow the naming conventions for a TST test procedure.'
         EXEC Internal.LogErrorMessage @ErrorMessage
         RETURN 1
      END
   END

   EXEC @ResultCode = Internal.PrepareTestSessionSetupInformation @TestSessionId, @TestProcedurePrefix
   IF(@ResultCode != 0) RETURN 1

   EXEC @ResultCode = Internal.PrepareTestSessionTeardownInformation @TestSessionId, @TestProcedurePrefix
   IF(@ResultCode != 0) RETURN 1

   DECLARE CrsTests CURSOR LOCAL FOR
   SELECT 
      SchemaName,
      SProcName
   FROM #Tmp_Procedures 
   WHERE
      SProcName LIKE (@TestProcedurePrefix + '%')
      AND (
               (SProcName = @TargetTestName) 
            OR (@TargetSuiteName IS NULL AND @TargetTestName IS NULL) 
            OR (SProcName = @TestProcedurePrefix + 'SETUP_' + @TargetSuiteName)
            OR (SProcName = @TestProcedurePrefix + 'TEARDOWN_' + @TargetSuiteName)
            OR (@TargetTestName IS NULL AND SProcName Like @TestProcedurePrefix + @TargetSuiteName + '#%')
          )
      AND SProcName != @TestProcedurePrefix + 'SESSION_SETUP'
      AND SProcName != @TestProcedurePrefix + 'SESSION_TEARDOWN'
               
   OPEN CrsTests
   FETCH NEXT FROM CrsTests INTO @SchemaName, @SProcName
   WHILE @@FETCH_STATUS = 0
   BEGIN
      EXEC Internal.AnalyzeSprocName @SProcName, @TestProcedurePrefix, @SuiteName OUTPUT, @IsTSTSproc OUTPUT, @SProcType OUTPUT
      IF(@IsTSTSproc = 1)
      BEGIN

         -- TODO: validate the suite and test name
         IF (@TargetSuiteName IS NULL OR @TargetSuiteName = @SuiteName)
         BEGIN

            EXEC Internal.EnsureSuite @TestSessionId, @SchemaName, @SuiteName, @SuiteId OUTPUT
            INSERT INTO Data.Test(TestSessionId, SuiteId, SchemaName, SProcName, SProcType) VALUES (@TestSessionId, @SuiteId, @SchemaName, @SProcName, @SProcType)
         END
                  
      END
     
      FETCH NEXT FROM CrsTests INTO @SchemaName, @SProcName
   END

   CLOSE CrsTests
   DEALLOCATE CrsTests
   
   -- If @TargetTestName is specified then it must exist
   IF (@TargetTestName IS NOT NULL)
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM Data.Test WHERE TestSessionId = @TestSessionId AND SProcName = @TargetTestName AND Test.SProcType = 'Test')
      BEGIN
         SET @ErrorMessage = 'Test procedure ''' + @TargetTestName + ''' not found in database ''' + @TestDatabaseName + '''.'
         EXEC Internal.LogErrorMessage @ErrorMessage
         RETURN 1
      END
   END

   IF (@TargetSuiteName IS NOT NULL)
   BEGIN
   
      -- If @TargetSuiteName is specified then it must exist.
      IF NOT EXISTS (SELECT 1 FROM Data.Suite WHERE TestSessionId = @TestSessionId AND SuiteName = @TargetSuiteName)
      BEGIN
         SET @ErrorMessage = 'Suite ''' + @TargetSuiteName + ''' not found in database ''' + @TestDatabaseName + '''.'
         EXEC Internal.LogErrorMessage @ErrorMessage
         RETURN 1
      END
   
      -- There must be at least one test defined for that suite.   
      IF NOT EXISTS (
         SELECT 1 
         FROM Data.Test 
         INNER JOIN Data.Suite ON Suite.SuiteId = Test.SuiteId
         WHERE Suite.TestSessionId = @TestSessionId AND Suite.SuiteName = @TargetSuiteName AND Test.SProcType = 'Test')
      BEGIN
         SET @ErrorMessage = 'Suite ''' + @TargetSuiteName + ''' in database ''' + @TestDatabaseName + ''' does not contain any test'
         EXEC Internal.LogErrorMessage @ErrorMessage
         RETURN 1
      END
   END
      
   -- There must be at least one test detected as a result of the analysis
   IF NOT EXISTS (
      SELECT 1 
      FROM Data.Test 
      WHERE Test.TestSessionId = @TestSessionId AND SProcType = 'Test')
   BEGIN
      SET @ErrorMessage = 'No test procedure was detected for the given search criteria in database ''' + @TestDatabaseName + '''.'
      EXEC Internal.LogErrorMessage @ErrorMessage
      RETURN 1
   END

   -- It is illegal to have two suites with the same name. This can happen if they are in different schemas.
   SET @DuplicateSuiteName = NULL
   SELECT @DuplicateSuiteName = SuiteName
   FROM TST.Data.Suite
   WHERE TestSessionId = @TestSessionId
   GROUP BY TestSessionId, SuiteName
   HAVING COUNT(*) > 1
   
   IF (@DuplicateSuiteName IS NOT NULL)
   BEGIN
      SET @ErrorMessage = 'The suite name ''' + @DuplicateSuiteName + ''' appears to be duplicated across different schemas in database ''' + @TestDatabaseName + '''.'
      EXEC Internal.LogErrorMessage @ErrorMessage
      RETURN 1
   END
   
   -- It is illegal to have two tests with the same name. This can happen if they are in the anonymous suite and in different schemas.
   SET @DuplicateTestName = NULL
   SELECT @DuplicateTestName = SProcName
   FROM TST.Data.Test
   WHERE TestSessionId = @TestSessionId
   GROUP BY TestSessionId, SProcName
   HAVING COUNT(*) > 1
   
   IF (@DuplicateTestName IS NOT NULL)
   BEGIN
      SET @ErrorMessage = 'The test name ''' + @DuplicateTestName + ''' appears to be duplicated across different schemas in database ''' + @TestDatabaseName + '''.'
      EXEC Internal.LogErrorMessage @ErrorMessage
      RETURN 1
   END

   RETURN 0
END
GO

-- =======================================================================
-- PROCEDURE SetTestSessionConfiguration
-- It searches for a stored procedure called TSTConfig in the tested 
-- database. If it exists it calls it. This allow tests to configure 
-- TST before proceeding with the test session.
--    0 - OK.
--    1 - An error was detected during the execution of TSTConfig.
--        In case of an error an error message is stored in one of the log tables.
-- =======================================================================
CREATE PROCEDURE Internal.SetTestSessionConfiguration
   @TestSessionId       int            -- Identifies the test session
AS
BEGIN

   DECLARE @SqlCommand        nvarchar(1000)
   DECLARE @TestDatabaseName  sysname
   DECLARE @PrepareResult     bit
   DECLARE @ErrorMessage      nvarchar(4000)   
   
   SET @PrepareResult = 0
   
   SELECT @TestDatabaseName = TestSession.DatabaseName FROM Data.TestSession WHERE TestSessionId = @TestSessionId

   IF (Internal.SFN_SProcExists(@TestDatabaseName, 'TSTConfig') = 1)
   BEGIN
      SET @SqlCommand = QUOTENAME(@TestDatabaseName) + '..' + QUOTENAME('TSTConfig')
      
      BEGIN TRY
         EXEC @SqlCommand
      END TRY
      BEGIN CATCH
         SET @ErrorMessage =  'An error occured during the execution of the TSTConfig procedure.' +
                              ' Error: ' + CAST(ERROR_NUMBER() AS varchar) + ', ' + ERROR_MESSAGE() + 
                              ' Procedure: ' + ISNULL(ERROR_PROCEDURE(), 'N/A') + '. Line: ' + CAST(ERROR_LINE() AS varchar)
         EXEC Internal.LogErrorMessage @ErrorMessage
         
         SET @PrepareResult = 1
      END CATCH

   END

   RETURN @PrepareResult
END
GO

-- =======================================================================
-- PROCEDURE PrepareTestSession
-- Must be called at the start of a test session. 
-- Return code:
--    0 - OK.
--    1 - An error was detected. 
--        In case of an error an error message is stored in one of the log tables.
-- =======================================================================
CREATE PROCEDURE Internal.PrepareTestSession
   @TestDatabaseName    sysname,       -- The database that contains the TST procedures.
   @TestSessionId       int OUT        -- At return it will identify the test session.
AS
BEGIN

   DECLARE @PrepareResult     bit

   IF (@TestDatabaseName IS NULL) 
   BEGIN
      RAISERROR('TST Internal Error. Invalid call to PrepareTestSession. @TestDatabaseName must be specified.', 16, 1)
      RETURN 1
   END

   -- Generate a new TestSessionId
   INSERT INTO Data.TestSession(DatabaseName, TestSessionStart, TestSessionFinish) VALUES (@TestDatabaseName, GETDATE(), NULL)
   SET @TestSessionId = SCOPE_IDENTITY()

   -- We will insert one row in #Tmp_CrtSessionInfo. This row is a placeholder 
   -- that we use to store info about what is the current TestSessionId, TestId
   -- This is how sprocs like Pass or Fail will know which test session 
   -- and which test are currently executed.
   -- Right now we are outside of any test stored procedure so we'll use -1 for TestId
   INSERT INTO #Tmp_CrtSessionInfo(TestSessionId, TestId, Stage) VALUES (@TestSessionId, -1, '-')

   -- Allow the user to set upconfiguration parameters   
   EXEC @PrepareResult = Internal.SetTestSessionConfiguration @TestSessionId
   
   RETURN @PrepareResult

END
GO

-- =======================================================================
-- PROCEDURE RunOneSProc
-- This will run the given TST test procedure. Caled by RunOneTestInternal
-- =======================================================================
CREATE PROCEDURE Internal.RunOneSProc
   @TestId           int               -- Identifies the test.
AS
BEGIN
   DECLARE @SqlCommand     nvarchar(1000)
   
   SET @SqlCommand = Internal.SFN_GetFullSprocName(@TestId)
   EXEC @SqlCommand

END
GO

-- =======================================================================
-- PROCEDURE RunSessionLevelSProc
-- This will run the given TST test procedure and pass it the 
-- parameter '@TestSessionId'.
-- =======================================================================
CREATE PROCEDURE Internal.RunSessionLevelSProc
   @TestSessionId       int,        -- Identifies the test session.
   @TestId              int         -- Identifies the test.
AS
BEGIN
   DECLARE @SqlCommand     nvarchar(1000)
   SET @SqlCommand = 'EXEC ' + Internal.SFN_GetFullSprocName(@TestId) + ' ' + CAST(@TestSessionId AS varchar)
   EXEC sp_executesql @SqlCommand
END
GO

-- =======================================================================
-- PROCEDURE RollbackWithLogPreservation
-- Rollbacks a transaction but makes sure that the entries in the log 
-- table TestLog are preserved.
-- =======================================================================
CREATE PROCEDURE Internal.RollbackWithLogPreservation
   @TestSessionId                   int,        -- Identifies the test session.
   @LastTestLogEntryIdBeforeTest    int         -- The last id that was present in the TestLog 
                                                -- table before the test execution started.
AS
BEGIN

   DECLARE @LastTestLogEntryIdAfterRollback  int

   -- @TempLogEntries will temporarily save the log entries that will dissapear due to the ROLLBACK
   DECLARE @TempLogEntries TABLE (
      LogEntryId     int NOT NULL,
      TestSProcId    int NOT NULL,
      EntryType      char NOT NULL,
      CreatedTime    DateTime NOT NULL,
      LogMessage     nvarchar(max) NOT NULL
   )

   DELETE FROM @TempLogEntries
   
   INSERT INTO @TempLogEntries(LogEntryId, TestSProcId, EntryType, CreatedTime, LogMessage) 
   SELECT LogEntryId, TestId, EntryType, CreatedTime, LogMessage 
   FROM Data.TestLog
   WHERE 
      LogEntryId > @LastTestLogEntryIdBeforeTest
      AND TestSessionId = @TestSessionId


   ROLLBACK TRANSACTION

   -- Determine which entries from TestLog did not survived
   SELECT @LastTestLogEntryIdAfterRollback = LogEntryId FROM Data.TestLog WHERE TestSessionId = @TestSessionId
   SET @LastTestLogEntryIdAfterRollback = ISNULL(@LastTestLogEntryIdAfterRollback, 0)

   -- Put back in table TestLog the entries that were lost due to the ROLLBACK 
   INSERT INTO Data.TestLog (TestSessionId, TestId, EntryType, CreatedTime, LogMessage)
   SELECT @TestSessionId, TestSProcId, EntryType, CreatedTime, LogMessage
   FROM @TempLogEntries
   WHERE LogEntryId > @LastTestLogEntryIdAfterRollback
   ORDER BY CreatedTime

END

GO

-- =======================================================================
-- PROCEDURE Rethrow
-- Implements the Rethrow functionality 
-- =======================================================================
CREATE PROCEDURE Internal.Rethrow
AS
BEGIN

   -- Return if there is no error information to retrieve.
   IF (ERROR_NUMBER() IS NULL) RETURN;

   DECLARE @ErrorMessage    nvarchar(4000)
   DECLARE @ErrorNumber     int
   DECLARE @ErrorSeverity   int
   DECLARE @ErrorState      int
   DECLARE @ErrorProcedure  nvarchar(200)
   DECLARE @ErrorLine       int

   -- Assign error-handling functions that capture the error information to variables.
   SELECT 
      @ErrorNumber       = ERROR_NUMBER()                ,
      @ErrorSeverity     = ERROR_SEVERITY()              ,
      @ErrorState        = ERROR_STATE()                 ,
      @ErrorProcedure    = ISNULL(ERROR_PROCEDURE(), 'N/A'),
      @ErrorLine         = ERROR_LINE()                  

   -- Build the message string that will contain the original error information.
   SELECT @ErrorMessage = 'Error %d, Level %d, State %d, Procedure %s, Line %d, Message: ' + ERROR_MESSAGE();

   -- Raise an error: msg_str parameter of RAISERROR will contain the original error information.
   -- Raise an error: msg_str parameter of RAISERROR will contain the original error information.
   RAISERROR (
      @ErrorMessage, 
      @ErrorSeverity, 
      1,               
      @ErrorNumber,    -- parameter: original error number.
      @ErrorSeverity,  -- parameter: original error severity.
      @ErrorState,     -- parameter: original error state.
      @ErrorProcedure, -- parameter: original error procedure name.
      @ErrorLine       -- parameter: original error line number.
      )

END
GO

-- =======================================================================
-- PROCEDURE CollectErrorInfo
-- Called from within inside a CATCH block. It processes the information 
-- in the ERROR_XXX functions. It examines XACT_STATE() and 
-- @@TRANCOUNT and based on all that it will return an error code.
-- Return code:
--    0 - This was an expected error as recorded by RegisterExpectedError.
--        No transaction was rolled back. The transaction if open is in 
--        a committable state. 
--    1 - Failure. Assert failure as oposed to an error. 
--    2 - Error. The test failed with an error. The transaction if open 
--               is in a committable state. The error was recorded and 
--               @ErrorMessage will be NULL.
--    3 - Error. The test failed with an error. The transaction is in an 
--               uncommittable state. @ErrorMessage will contain the error 
--               text. 
--    4 - Error. The transaction was rolled back. Normally this is acompanied 
--               by a 266 or 3609 error:
--                226: Transaction count after EXECUTE indicates that a COMMIT or ROLLBACK TRAN is missing
--               3609: The transaction ended in the trigger.
--               The error was recorded and @ErrorMessage will be NULL.
--    5 - This was an expected error as recorded by RegisterExpectedError.
--        No transaction was rolled back. However the transaction is in 
--        an uncommittable state. 
-- =======================================================================
CREATE PROCEDURE Internal.CollectErrorInfo
   @TestId                       int,                -- Identifies the test where the error occured.
   @UseTSTRollback               bit,                -- 1 if TSTRollback is enabled.
   @StartTranCount               int,                -- The transaction count before the setup procedure was invoked.
   @ErrorMessage                 nvarchar(max) OUT,  -- If an error occured it will contain the error text
   @NestedTransactionMessage     nvarchar(max) OUT   -- If a nested transaction caused issues this will have an error message regarding that.
AS 
BEGIN

   DECLARE @TSTRollbackMessage         nvarchar(4000)
   DECLARE @InProcedureMsg             nvarchar(100)
   DECLARE @FullSprocName              nvarchar(1000)

   DECLARE @Catch_ErrorMessage   nvarchar(2048) 
   DECLARE @Catch_ErrorProcedure nvarchar(126)
   DECLARE @Catch_ErrorLine      int
   DECLARE @Catch_ErrorNumber    int

   DECLARE @ExpectedErrorNumber       int
   DECLARE @ExpectedErrorMessage      nvarchar(2048) 
   DECLARE @ExpectedErrorProcedure    nvarchar(126)
   DECLARE @IsExpectedError           bit

   SET @Catch_ErrorMessage   = ERROR_MESSAGE()
   SET @Catch_ErrorProcedure = ERROR_PROCEDURE()
   SET @Catch_ErrorLine      = ERROR_LINE()
   SET @Catch_ErrorNumber    = ERROR_NUMBER()

   -- If this is an error raised by the TST API (like Assert) we don't have to log the error, it was already logged.
   IF (@Catch_ErrorMessage = 'TST RAISERROR {6C57D85A-CE44-49ba-9286-A5227961DF02}') RETURN 1

   -- Check if this is an expected error.
   SET @IsExpectedError = 0
   SELECT 
      @ExpectedErrorNumber       = ExpectedErrorNumber    ,
      @ExpectedErrorMessage      = ExpectedErrorMessage   ,
      @ExpectedErrorProcedure    = ExpectedErrorProcedure 
   FROM #Tmp_CrtSessionInfo
   
   IF ( (@ExpectedErrorNumber IS NOT NULL) OR (@ExpectedErrorMessage IS NOT NULL) OR (@ExpectedErrorProcedure IS NOT NULL) )
   BEGIN
      IF (      (@Catch_ErrorNumber    = @ExpectedErrorNumber    OR @ExpectedErrorNumber IS NULL      )
            AND (@Catch_ErrorMessage   = @ExpectedErrorMessage   OR @ExpectedErrorMessage IS NULL     )
            AND (@Catch_ErrorProcedure = @ExpectedErrorProcedure OR @ExpectedErrorProcedure IS NULL   ) )
      BEGIN
         SET @IsExpectedError = 1
      END
   END
      
   IF (@UseTSTRollback = 1)
   BEGIN
      IF (@Catch_ErrorNumber = 266 OR @Catch_ErrorNumber = 3609 OR @@TRANCOUNT != @StartTranCount)
      BEGIN
      
         SET @TSTRollbackMessage = 'To disable TST rollback create a stored procedure called TSTConfig in the database where you ' +
                        'have the test procedures. Inside TSTConfig call ' + 
                        '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. ' + 
                        'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
                        'See TST documentation for more details.'

         IF (@Catch_ErrorProcedure IS NULL) SET @InProcedureMsg = ''
         ELSE SET @InProcedureMsg = ' in procedure ''' + @Catch_ErrorProcedure + ''''

         IF (@Catch_ErrorNumber = 266 OR @@TRANCOUNT != @StartTranCount)
         BEGIN
            IF (@@TRANCOUNT > 0)
            BEGIN
               SET @NestedTransactionMessage =  'BEGIN TRANSACTION with no matching COMMIT detected' + 
                                    @InProcedureMsg + '. ' + 
                                    'Please disable the TST rollback if you expect the tested procedure to use BEGIN TRANSACTION with no matching COMMIT. ' + 
                                    @TSTRollbackMessage
            END
            ELSE
            BEGIN
               SET @NestedTransactionMessage =  'ROLLBACK TRANSACTION detected' + 
                                    @InProcedureMsg + '. ' + 
                                    'All other TST messages logged during this test and previous to this error were lost. ' + 
                                    'Please disable the TST rollback if you expect the tested procedure to use ROLLBACK TRANSACTION. ' + 
                                    @TSTRollbackMessage
            END
         END
         ELSE
         BEGIN
            IF (@@TRANCOUNT > 0)
            BEGIN
               SET @NestedTransactionMessage =  'BEGIN TRANSACTION with no matching COMMIT detected during trigger execution' + 
                                    @InProcedureMsg + '. ' + 
                                    'This looks like a bug in the trigger and you should consider fixing that. ' + 
                                    'Alternatively you can disable the TST rollback if you expect the trigger to use BEGIN TRANSACTION with no matching COMMIT. ' + 
                                    @TSTRollbackMessage
            END
            ELSE
            BEGIN
               SET @NestedTransactionMessage =  'ROLLBACK TRANSACTION detected during trigger execution' + 
                                    @InProcedureMsg + '. ' + 
                                    'Please disable the TST rollback if you expect the trigger to use ROLLBACK TRANSACTION. ' + 
                                    @TSTRollbackMessage
            END
         END
      END
   END
      
   IF (@IsExpectedError = 1)
   BEGIN
      IF (XACT_STATE() = -1)  RETURN 5    -- Expected error but the transaction is in a uncommittable state.
      IF (@@TRANCOUNT != @StartTranCount AND @@TRANCOUNT = 0) RETURN 4
      RETURN 0
   END
   ELSE
   BEGIN
      SET @FullSprocName = Internal.SFN_GetFullSprocName(@TestId)
      SET @ErrorMessage =  'An error occured during the execution of the test procedure ''' + @FullSprocName + 
                           '''. Error: ' + CAST(ERROR_NUMBER() AS varchar) + ', ' + ERROR_MESSAGE() + 
                           ' Procedure: ' + ISNULL(ERROR_PROCEDURE(), 'N/A') + '. Line: ' + CAST(ERROR_LINE() AS varchar)

      IF (XACT_STATE() = -1)  RETURN 3    -- The transaction is in a uncommittable state.

      IF (@IsExpectedError = 0) 
      BEGIN
         
         IF (@ErrorMessage IS NOT NULL)               
         BEGIN
            EXEC Internal.LogErrorMessage @ErrorMessage; SET @ErrorMessage = NULL
         END
         
         IF (@NestedTransactionMessage IS NOT NULL)   
         BEGIN
            EXEC Internal.LogErrorMessage @NestedTransactionMessage; SET @NestedTransactionMessage = NULL
         END
         
      END

      IF (@@TRANCOUNT != @StartTranCount AND @@TRANCOUNT = 0) RETURN 4
      RETURN 2
   END
   
END
GO


-- =======================================================================
-- PROCEDURE CollectSetupSProcErrorInfo
-- Called from within inside a CATCH block. It processes the information 
-- in the ERROR_XXX functions. It examines XACT_STATE() and 
-- @@TRANCOUNT and based on all that it will return an error code.
-- If the active transaction is in an uncommitable state it will do a 
-- ROLLBACK while preserving the entries in the TestLog table.
-- Return code:
--    1 - Error or failure but the execution can continue with the teardown.
--    2 - Error and the test execution has to be aborted.
-- =======================================================================
CREATE PROCEDURE Internal.CollectSetupSProcErrorInfo
   @TestSessionId                int,              -- Identifies the test session.
   @SetupSProcId                 int,              -- Identifies the setup proc where the error occured.
   @UseTSTRollback               bit,              -- 1 if TSTRollback is enabled.
   @StartTranCount               int,              -- The transaction count before the setup procedure was invoked.
   @LastTestLogEntryIdBeforeTest int               -- The last id that was present in the TestLog 
                                                   -- table before the test execution started.
AS
BEGIN

   DECLARE @ErrorCode                     int
   DECLARE @ReturnCode                    int
   DECLARE @FullSprocName                 nvarchar(1000)
   DECLARE @ErrorMessage                  nvarchar(max)  -- If an error occured it will contain the error text
   DECLARE @NestedTransactionMessage      nvarchar(max)  -- If a nested transaction caused issues this will have an error message regarding that.
   DECLARE @TransactionWarningMessage     nvarchar(max)  -- If the teardown will have to be invoked outside of the context of a transaction 
                                                         -- this will have an error message regarding that.

   SET @ReturnCode = -1

   EXEC @ErrorCode = Internal.CollectErrorInfo  
                           @SetupSProcId, 
                           @StartTranCount, 
                           @UseTSTRollback, 
                           @ErrorMessage OUT,
                           @NestedTransactionMessage OUT
   
   -- We do not allow "Expected errors" during the Setup.
   -- If during the Setup we get an "Expected errors" we will record an error.
   IF (@ErrorCode = 0) SET @ErrorCode = 2
   IF (@ErrorCode = 5) SET @ErrorCode = 2

   IF      (@UseTSTRollback = 1 AND @ErrorCode = 1)  SET @ReturnCode = 1
   ELSE IF (@UseTSTRollback = 1 AND @ErrorCode = 2)  SET @ReturnCode = 1
   ELSE IF (@UseTSTRollback = 1 AND @ErrorCode = 3)   
   BEGIN
      -- The transaction is in an invalid (uncomittable) state. We need to roll it back.
      SET @FullSprocName = Internal.SFN_GetFullSprocName(@SetupSProcId)
      SET @TransactionWarningMessage = 'The transaction is in an uncommitable state after the setup procedure ''' + @FullSprocName + ''' has failed. A rollback was forced. The TEARDOWN if any will be executed outside of a transaction scope.'
      SET @ReturnCode = 1
      
      GOTO LblSaveLogAndRollback
   END
   ELSE IF (@UseTSTRollback = 1 AND @ErrorCode = 4)   
   BEGIN
      SET @FullSprocName = Internal.SFN_GetFullSprocName(@SetupSProcId)
      SET @TransactionWarningMessage = 'The transaction was rolled back during the setup procedure ''' + @FullSprocName + '''. The TEARDOWN if any will be executed outside of a transaction scope.'
      SET @ReturnCode = 1
   END
   ELSE IF (@UseTSTRollback = 0 AND @ErrorCode = 1)  SET @ReturnCode = 1
   ELSE IF (@UseTSTRollback = 0 AND @ErrorCode = 2)  SET @ReturnCode = 1
   IF (@UseTSTRollback = 0 AND @ErrorCode = 3)   
   BEGIN
      -- If we did not begin a transaction but now we have a transaction in an uncommitable state 
      -- then it means that the client opened it. We will rollback the transaction.
      SET @FullSprocName = Internal.SFN_GetFullSprocName(@SetupSProcId)
      SET @TransactionWarningMessage = 'The setup procedure ''' + @FullSprocName + ''' opened a transaction that is now in an uncommitable state. A rollback was forced. The TEARDOWN if any will be executed outside of a transaction scope.'
      SET @ReturnCode = 1
      
      GOTO LblSaveLogAndRollback
   END
   -- ELSE IF (@UseTSTRollback = 0 AND @ErrorCode = 4) This cannot happen. We will leave @ReturnCode set to -1 which will generate an internal error

   GOTO LblSaveErrors

LblSaveLogAndRollback:

   BEGIN TRY
      -- Rollback and in the same time preserves the log entries
      EXEC Internal.RollbackWithLogPreservation @TestSessionId, @LastTestLogEntryIdBeforeTest
   END TRY
   BEGIN CATCH
      -- RollbackWithLogPreservation will execute a ROLLBACK transaction so an error 266 caused by @@Trancount mismatch is expected. 
      IF (ERROR_NUMBER() != 266) EXEC Internal.Rethrow
   END CATCH

LblSaveErrors:

   IF (@ErrorMessage                 IS NOT NULL)  EXEC Internal.LogErrorMessage @ErrorMessage
   IF (@NestedTransactionMessage     IS NOT NULL)  EXEC Internal.LogErrorMessage @NestedTransactionMessage
   IF (@TransactionWarningMessage    IS NOT NULL)  EXEC Internal.LogErrorMessage @TransactionWarningMessage

   IF (@ReturnCode < 0)
   BEGIN 
      EXEC Internal.LogErrorMessage 'TST Internal Error in CollectSetupSProcErrorInfo. Unexpected error code'
      SET @ReturnCode = 1
   END

   RETURN @ReturnCode

END
GO

-- =======================================================================
-- PROCEDURE CollectTeardownSProcErrorInfo
-- Called from within inside a CATCH block. It processes the information 
-- in the ERROR_XXX functions. It examines XACT_STATE() and 
-- @@TRANCOUNT and based on all that it will return an error code.
-- If the active transaction is in an uncommitable state it will do a 
-- ROLLBACK while preserving the entries in the TestLog table.
-- Return code: 1
-- =======================================================================
CREATE PROCEDURE Internal.CollectTeardownSProcErrorInfo
   @TestSessionId                int,              -- Identifies the test session.
   @TeardownSProcId              int,              -- Identifies the teardown proc where the error occured.
   @UseTSTRollback               bit,              -- 1 if TSTRollback is enabled.
   @StartTranCount               int,              -- The transaction count before the setup procedure was invoked.
   @LastTestLogEntryIdBeforeTest int               -- The last id that was present in the TestLog 
                                                   -- table before the test execution started.
AS
BEGIN

   DECLARE @ErrorCode                     int
   DECLARE @ReturnCode                    int
   DECLARE @FullSprocName                 nvarchar(1000)
   DECLARE @ErrorMessage                  nvarchar(max)  -- If an error occured it will contain the error text
   DECLARE @NestedTransactionMessage      nvarchar(max)  -- If a nested transaction caused issues this will have an error message regarding that.
   DECLARE @TransactionWarningMessage     nvarchar(max)  -- If the teardown will have to be invoked outside of the context of a transaction 
                                                         -- this will have an error message regarding that.

   SET @ReturnCode = -1

   EXEC @ErrorCode = Internal.CollectErrorInfo  
                           @TeardownSProcId, 
                           @StartTranCount, 
                           @UseTSTRollback, 
                           @ErrorMessage OUT,
                           @NestedTransactionMessage OUT

   -- We do not allow "Expected errors" during the Teardown.
   -- If during the Teardown we get an "Expected errors" we will record an error.
   IF (@ErrorCode = 0) SET @ErrorCode = 2
   IF (@ErrorCode = 5) SET @ErrorCode = 2

   IF      (@UseTSTRollback = 1 AND @ErrorCode = 1)  SET @ReturnCode = 1
   ELSE IF (@UseTSTRollback = 1 AND @ErrorCode = 2)  SET @ReturnCode = 1
   ELSE IF (@UseTSTRollback = 1 AND @ErrorCode = 3)   
   BEGIN
      -- The transaction is in an invalid (uncomittable) state. We need to roll it back.
      SET @FullSprocName = Internal.SFN_GetFullSprocName(@TeardownSProcId)
      SET @TransactionWarningMessage = 'The transaction is in an uncommitable state after the teardown procedure ''' + @FullSprocName + ''' has failed. A rollback was forced.'
      SET @ReturnCode = 1
      
      GOTO LblSaveLogAndRollback
   END
   ELSE IF (@UseTSTRollback = 1 AND @ErrorCode = 4)   
   BEGIN
      SET @FullSprocName = Internal.SFN_GetFullSprocName(@TeardownSProcId)
      SET @TransactionWarningMessage = 'The transaction was rolled back during the teardown procedure ''' + @FullSprocName + '''.'
      SET @ReturnCode = 1
   END
   ELSE IF (@UseTSTRollback = 0 AND @ErrorCode = 1)  SET @ReturnCode = 1
   ELSE IF (@UseTSTRollback = 0 AND @ErrorCode = 2)  SET @ReturnCode = 1
   IF (@UseTSTRollback = 0 AND @ErrorCode = 3)   
   BEGIN
      -- If we did not begin a transaction but now we have a transaction in an uncommitable state 
      -- then it means that the client opened it. We will rollback the transaction.
      SET @FullSprocName = Internal.SFN_GetFullSprocName(@TeardownSProcId)
      SET @TransactionWarningMessage = 'The teardown procedure ''' + @FullSprocName + ''' opened a transaction that is now in an uncommitable state. A rollback was forced.'
      SET @ReturnCode = 1
      
      GOTO LblSaveLogAndRollback
   END
   -- ELSE IF (@UseTSTRollback = 0 AND @ErrorCode = 4) This cannot happen. We will live @ReturnCode set to -1 which will generate an internal error

   GOTO LblSaveErrors

LblSaveLogAndRollback:

   BEGIN TRY
      -- Rollback and in the same time preserves the log entries
      EXEC Internal.RollbackWithLogPreservation @TestSessionId, @LastTestLogEntryIdBeforeTest
   END TRY
   BEGIN CATCH
      -- RollbackWithLogPreservation will execute a ROLLBACK transaction so an error 266 caused by @@Trancount mismatch is expected. 
      IF (ERROR_NUMBER() != 266) EXEC Internal.Rethrow
   END CATCH

LblSaveErrors:

   IF (@ErrorMessage                 IS NOT NULL)  EXEC Internal.LogErrorMessage @ErrorMessage
   IF (@NestedTransactionMessage     IS NOT NULL)  EXEC Internal.LogErrorMessage @NestedTransactionMessage
   IF (@TransactionWarningMessage    IS NOT NULL)  EXEC Internal.LogErrorMessage @TransactionWarningMessage

   IF (@ReturnCode < 0)
   BEGIN 
      EXEC Internal.LogErrorMessage 'TST Internal Error in CollectTeardownSProcErrorInfo. Unexpected error code'
      SET @ReturnCode = 1
   END

   RETURN @ReturnCode

END
GO

-- =======================================================================
-- PROCEDURE CollectTestSProcErrorInfo
-- Called from within inside a CATCH block. It processes the information 
-- in the ERROR_XXX functions. It examines XACT_STATE() and 
-- @@TRANCOUNT and based on all that it will return an error code.
-- If the active transaction is in an uncommitable state it will do a 
-- ROLLBACK while preserving the entries in the TestLog table.
-- Return code:
--    0 - There was an error but it was expected as recorded by 
--        RegisterExpectedError. No transaction was rolled back. The 
--        transaction if open is in a committable state. 
--    1 - Error or failure but the execution can continue with the teardown.
--    2 - Error and the test execution has to be aborted.
-- =======================================================================
CREATE PROCEDURE Internal.CollectTestSProcErrorInfo
   @TestSessionId                int,              -- Identifies the test session.
   @TestSProcId                  int,              -- Identifies the test where the error occured.
   @UseTSTRollback               bit,              -- 1 if TSTRollback is enabled.
   @UseTeardown                  bit,              -- 1 if a teardown is useed.
   @StartTranCount               int,              -- The transaction count before the setup procedure was invoked.
   @LastTestLogEntryIdBeforeTest int               -- The last id that was present in the TestLog 
                                                   -- table before the test execution started.
AS
BEGIN

   DECLARE @ErrorCode                     int
   DECLARE @ReturnCode                    int
   DECLARE @FullSprocName                 nvarchar(1000)
   DECLARE @ErrorMessage                  nvarchar(max)  -- If an error occured it will contain the error text
   DECLARE @NestedTransactionMessage      nvarchar(max)  -- If a nested transaction caused issues this will have an error message regarding that.
   DECLARE @TransactionWarningMessage     nvarchar(max)  -- If the teardown will have to be invoked outside of the context of a transaction 
                                                         -- this will have an error message regarding that.
   DECLARE @TransactionInfoMessage        nvarchar(max)  -- The transaction is in an uncommited state. However this message is for a scenario where the reansaction can be rolled back without ill effects.

   SET @ReturnCode = -1
   
   EXEC @ErrorCode = Internal.CollectErrorInfo  
                           @TestSProcId, 
                           @StartTranCount, 
                           @UseTSTRollback, 
                           @ErrorMessage OUT,
                           @NestedTransactionMessage OUT

   IF      (@UseTSTRollback = 1 AND @ErrorCode = 0)   SET @ReturnCode = 0
   ELSE IF (@UseTSTRollback = 1 AND @ErrorCode = 1)   SET @ReturnCode = 1
   ELSE IF (@UseTSTRollback = 1 AND @ErrorCode = 2)   SET @ReturnCode = 1
   ELSE IF (@UseTSTRollback = 1 AND @ErrorCode = 3)   
   BEGIN
      -- The transaction is in an invalid (uncomittable) state. We need to roll it back.
      SET @FullSprocName = Internal.SFN_GetFullSprocName(@TestSProcId)
      SET @TransactionWarningMessage = 'The transaction is in an uncommitable state after the test procedure ''' + @FullSprocName + ''' has failed. A rollback was forced. The TEARDOWN if any will be executed outside of a transaction scope.'
      SET @ReturnCode = 1

      GOTO LblSaveLogAndRollback
   END
   ELSE IF (@UseTSTRollback = 1 AND @ErrorCode = 4)   
   BEGIN
      SET @FullSprocName = Internal.SFN_GetFullSprocName(@TestSProcId)
      SET @TransactionWarningMessage = 'The transaction was rolled back during the test procedure ''' + @FullSprocName + '''. The TEARDOWN if any will be executed outside of a transaction scope.'
      SET @ReturnCode = 1
   END
   ELSE IF (@UseTSTRollback = 1 AND @ErrorCode = 5)
   BEGIN
      IF @UseTeardown = 0
      BEGIN
         SET @FullSprocName = Internal.SFN_GetFullSprocName(@TestSProcId)
         SET @TransactionInfoMessage = 'The transaction is in an uncommitable state after the test procedure ''' + @FullSprocName + ''' has failed. A rollback was forced but the test will complete.'
         SET @ReturnCode = 0
         GOTO LblSaveLogAndRollback
      END
      ELSE
      BEGIN
         SET @FullSprocName = Internal.SFN_GetFullSprocName(@TestSProcId)
         SET @TransactionWarningMessage = 'The transaction is in an uncommitable state after the test procedure ''' + @FullSprocName + ''' has failed. A rollback was forced. The TEARDOWN will be executed outside of a transaction scope.'
         SET @ReturnCode = 1
         GOTO LblSaveLogAndRollback
      END
   END
   ELSE IF (@UseTSTRollback = 0 AND @ErrorCode = 0)   SET @ReturnCode = 0
   ELSE IF (@UseTSTRollback = 0 AND @ErrorCode = 1)   SET @ReturnCode = 1
   ELSE IF (@UseTSTRollback = 0 AND @ErrorCode = 2)   SET @ReturnCode = 1
   ELSE IF (@UseTSTRollback = 0 AND @ErrorCode = 3)
   BEGIN
      -- If we did not begin a transaction but now we have a transaction in an uncommitable state 
      -- then it means that the client opened it. We will rollback the transaction.
      SET @FullSprocName = Internal.SFN_GetFullSprocName(@TestSProcId)
      SET @TransactionWarningMessage = 'The test procedure ''' + @FullSprocName + ''' opened a transaction that is now in an uncommitable state. A rollback was forced. The TEARDOWN if any will be executed outside of a transaction scope.'
      SET @ReturnCode = 1
      
      GOTO LblSaveLogAndRollback
   END
   -- ELSE IF (@UseTSTRollback = 0 AND @ErrorCode = 4) This cannot happen. We won't see @ErrorCode = 4 in the absence of the auto-rollback. We will leave @ReturnCode set to -1 which will generate an internal error.
   -- ELSE IF (@UseTSTRollback = 0 AND @ErrorCode = 5) This cannot happen. We won't see @ErrorCode = 5 in the absence of the auto-rollback. We will leave @ReturnCode set to -1 which will generate an internal error.

   GOTO LblSaveErrors

LblSaveLogAndRollback:

   BEGIN TRY
      -- Rollback and in the same time preserves the log entries
      EXEC Internal.RollbackWithLogPreservation @TestSessionId, @LastTestLogEntryIdBeforeTest
   END TRY
   BEGIN CATCH
      -- RollbackWithLogPreservation will execute a ROLLBACK transaction so an error 266 caused by @@Trancount mismatch is expected. 
      IF (ERROR_NUMBER() != 266) EXEC Internal.Rethrow
   END CATCH

LblSaveErrors:

   IF (@ErrorMessage                 IS NOT NULL)  EXEC Internal.LogErrorMessage @ErrorMessage
   IF (@NestedTransactionMessage     IS NOT NULL)  EXEC Internal.LogErrorMessage @NestedTransactionMessage
   IF (@TransactionWarningMessage    IS NOT NULL)  EXEC Internal.LogErrorMessage @TransactionWarningMessage
   IF (@TransactionInfoMessage       IS NOT NULL)  EXEC Internal.LogInfoMessage @TransactionInfoMessage
   

   IF (@ReturnCode < 0)
   BEGIN 
      EXEC Internal.LogErrorMessage 'TST Internal Error in CollectTestSProcErrorInfo. Unexpected error code'
      SET @ReturnCode = 1
   END

   RETURN @ReturnCode

END
GO


-- =======================================================================
-- PROCEDURE GetExpectedErrorInfo
-- Retrieves information about the current expected error. 
-- If no expected error is registered then at return 
-- @ExpectedErrorContextMessage and @ExpectedErrorInfo will be NULL.
-- If an expected error is registered then at return 
-- @ExpectedErrorContextMessage and @ExpectedErrorInfo will contain the 
-- appropiate information (See RegisterExpectedError)
-- =======================================================================
CREATE PROCEDURE Internal.GetExpectedErrorInfo
   @ExpectedErrorContextMessage  nvarchar(1000) OUT, 
   @ExpectedErrorInfo            nvarchar(2000) OUT 
AS
BEGIN

   DECLARE @ExpectedErrorNumber           int
   DECLARE @ExpectedErrorMessage          nvarchar(2048) 
   DECLARE @ExpectedErrorProcedure        nvarchar(126)

   SET @ExpectedErrorInfo           = NULL
   SET @ExpectedErrorContextMessage = NULL

   SELECT 
      @ExpectedErrorNumber          = ExpectedErrorNumber         ,
      @ExpectedErrorMessage         = ExpectedErrorMessage        ,
      @ExpectedErrorProcedure       = ExpectedErrorProcedure      ,
      @ExpectedErrorContextMessage  = ExpectedErrorContextMessage
   FROM #Tmp_CrtSessionInfo

   IF (     (@ExpectedErrorNumber IS NOT NULL) 
         OR (@ExpectedErrorMessage IS NOT NULL) 
         OR (@ExpectedErrorProcedure IS NOT NULL) )
   BEGIN
      SET @ExpectedErrorInfo = 
         'Error number: ' + ISNULL(CAST(@ExpectedErrorNumber AS varchar), 'N/A') +
         ' Procedure: ''' + ISNULL(@ExpectedErrorProcedure, 'N/A') + '''' + 
         ' Message: ' + ISNULL(@ExpectedErrorMessage, 'N/A')
      SET @ExpectedErrorContextMessage = ISNULL(@ExpectedErrorContextMessage, '')
   END
   
END
GO


-- =======================================================================
-- PROCEDURE RunOneTestInternal
-- Runs a given test including its suite and teardown if defined. 
-- Implements the TST Rollback: will run the test in the context of a 
-- transaction that will be reverted at the end.
-- Note: The TST Rollback can be disabled.
-- =======================================================================
CREATE PROCEDURE Internal.RunOneTestInternal
   @TestSessionId    int,     -- Identifies the test session.
   @TestSProcId      int,     -- Identifies the test stored procedure.
   @SetupSProcId     int,     -- Identifies the setup stored procedure.
   @TeardownSProcId  int      -- Identifies the teardown stored procedure.
AS
BEGIN

   DECLARE @LastTestLogEntryIdBeforeTest  int
   DECLARE @UseTSTRollback                bit
   DECLARE @UseTeardown                   bit
   DECLARE @SetupSprocErrorCode           int
   DECLARE @TestSprocErrorCode            int
   DECLARE @TeardownSprocErrorCode        int

   DECLARE @ExpectedErrorContextMessage   nvarchar(1000)
   DECLARE @ExpectedErrorInfo             nvarchar(4000)
   DECLARE @FullSprocName                 nvarchar(1000)
   DECLARE @Message                       nvarchar(max)
   DECLARE @StartTranCount                int


   UPDATE #Tmp_CrtSessionInfo SET TestId = @TestSProcId
   EXEC Internal.ClearExpectedError

   -- EXEC Utils.DropTestTables

   SET @UseTSTRollback = Internal.SFN_UseTSTRollbackForTest(@TestSessionId, @TestSProcId)
   IF (@UseTSTRollback = 1)
   BEGIN
      BEGIN TRANSACTION 
   END

   SET @UseTeardown = 0
   IF (@TeardownSProcId IS NOT NULL)
   BEGIN
      SET @UseTeardown = 1
   END

   SET @StartTranCount = @@TRANCOUNT
   
   SELECT @LastTestLogEntryIdBeforeTest = LogEntryId FROM Data.TestLog WHERE TestSessionId = @TestSessionId
   SET @LastTestLogEntryIdBeforeTest = ISNULL(@LastTestLogEntryIdBeforeTest, 0)

   --================================
   -- SETUP
   --================================
   IF (@SetupSProcId IS NOT NULL) 
   BEGIN TRY
      UPDATE #Tmp_CrtSessionInfo SET Stage = 'S'
      EXEC Internal.RunOneSProc @SetupSProcId
   END TRY
   BEGIN CATCH
      BEGIN TRY
         EXEC @SetupSprocErrorCode = Internal.CollectSetupSProcErrorInfo
                                          @TestSessionId                 = @TestSessionId,
                                          @SetupSProcId                  = @SetupSProcId,
                                          @UseTSTRollback                = @UseTSTRollback,
                                          @StartTranCount                = @StartTranCount,
                                          @LastTestLogEntryIdBeforeTest  = @LastTestLogEntryIdBeforeTest
      END TRY
      BEGIN CATCH
         -- Some scenarios may cause CollectSetupSProcErrorInfo to rollback transactions. 
         -- When that happens the @@TRANCOUNT mismatch will trigger an error with error number 266. We'll ignore that error here.
         IF (ERROR_NUMBER() != 266) EXEC Internal.Rethrow
      END CATCH
      
      IF (@SetupSprocErrorCode = 0) GOTO LblBeforeTest
      IF (@SetupSprocErrorCode = 1) GOTO LblBeforeTeardown
      IF (@SetupSprocErrorCode = 2) GOTO LblPostTest

   END CATCH

LblBeforeTest:

   --================================
   -- TEST
   --================================
   BEGIN TRY
      UPDATE #Tmp_CrtSessionInfo SET Stage = 'T'
      EXEC Internal.RunOneSProc @TestSProcId

      -- Check if we were supposed to get an error.
      EXEC Internal.GetExpectedErrorInfo @ExpectedErrorContextMessage OUT, @ExpectedErrorInfo OUT 
      IF( @ExpectedErrorContextMessage IS NOT NULL)
      BEGIN
         SET @FullSprocName = Internal.SFN_GetFullSprocName(@TestSProcId)
         SET @Message = 'Test ' + @FullSprocName + ' failed. [' + @ExpectedErrorContextMessage + '] Expected error was not raised: ' + @ExpectedErrorInfo
         EXEC Assert.Fail @Message
      END
   END TRY
   BEGIN CATCH
      BEGIN TRY
         -- We will collect the info about an expected error (if any) at this point. There are scenarios where this info 
         -- is lost during CollectTestSProcErrorInfo. That is the case when we are forced to do a rollback in CollectTestSProcErrorInfo.
         EXEC Internal.GetExpectedErrorInfo @ExpectedErrorContextMessage OUT, @ExpectedErrorInfo OUT 

         EXEC @TestSprocErrorCode = Internal.CollectTestSProcErrorInfo
                                       @TestSessionId                 = @TestSessionId,
                                       @TestSProcId                   = @TestSProcId,
                                       @UseTSTRollback                = @UseTSTRollback,
                                       @UseTeardown                   = @UseTeardown,
                                       @StartTranCount                = @StartTranCount,
                                       @LastTestLogEntryIdBeforeTest  = @LastTestLogEntryIdBeforeTest
      END TRY
      BEGIN CATCH
         -- Some scenarios may cause CollectTestSProcErrorInfo to rollback transactions. 
         -- When that happens the @@TRANCOUNT mismatch will trigger an error with error number 266. We'll ignore that error here.
         IF (ERROR_NUMBER() != 266) EXEC Internal.Rethrow
      END CATCH
      
      IF (@TestSprocErrorCode = 0) 
      BEGIN
         SET @FullSprocName = Internal.SFN_GetFullSprocName(@TestSProcId)
         SET @Message = 'Test ' + @FullSprocName + ' passed. [' + @ExpectedErrorContextMessage + '] Expected error was raised: ' + @ExpectedErrorInfo
         EXEC Assert.Pass @Message

         GOTO LblBeforeTeardown
      END
      IF (@TestSprocErrorCode = 1) GOTO LblBeforeTeardown
      IF (@TestSprocErrorCode = 2) GOTO LblPostTest

   END CATCH

LblBeforeTeardown:
   --================================
   -- TEARDOWN
   --================================
   IF (@TeardownSProcId IS NOT NULL)
   BEGIN TRY
      UPDATE #Tmp_CrtSessionInfo SET Stage = 'X'
      EXEC Internal.RunOneSProc @TeardownSProcId
   END TRY
   BEGIN CATCH
      BEGIN TRY
         EXEC @TeardownSprocErrorCode = Internal.CollectTeardownSProcErrorInfo
                                                @TestSessionId                 = @TestSessionId,
                                                @TeardownSProcId               = @TeardownSProcId,
                                                @UseTSTRollback                = @UseTSTRollback,
                                                @StartTranCount                = @StartTranCount,
                                                @LastTestLogEntryIdBeforeTest  = @LastTestLogEntryIdBeforeTest
      END TRY
      BEGIN CATCH
         -- Some scenarios may cause CollectTeardownSProcErrorInfo to rollback transactions. 
         -- When that happens the @@TRANCOUNT mismatch will trigger an error with error number 266. We'll ignore that error here.
         IF (ERROR_NUMBER() != 266) EXEC Internal.Rethrow
      END CATCH
     
   END CATCH

LblPostTest:

   IF (@@TRANCOUNT > 0)
   BEGIN
      BEGIN TRY
         -- Rollback and in the same time preserves the log entries
         EXEC Internal.RollbackWithLogPreservation @TestSessionId, @LastTestLogEntryIdBeforeTest
      END TRY
      BEGIN CATCH
         -- RollbackWithLogPreservation will execute a ROLLBACK transaction so an error 266 caused by @@Trancount mismatch is expected. 
         IF (ERROR_NUMBER() != 266) EXEC Internal.Rethrow
      END CATCH
   END

END
GO


-- =======================================================================
-- PROCEDURE RunOneSuiteInternal
-- Runs a given test suite. 
-- =======================================================================
CREATE PROCEDURE Internal.RunOneSuiteInternal
   @TestSessionId    int,              -- Identifies the test session.
                                       -- Note: this is provided as a optimization. It could be determined based on @SuiteId
   @SuiteId          int               -- Identifies the suite.
AS
BEGIN

   DECLARE @TestSProcId             int
   DECLARE @SetupSProcId            int
   DECLARE @TeardownSProcId         int
   DECLARE @ErrorMessage            nvarchar(4000)
   
   SELECT @SetupSProcId    = TestId FROM Data.Test WHERE SuiteId = @SuiteId AND SProcType = 'Setup'
   SELECT @TeardownSProcId = TestId FROM Data.Test WHERE SuiteId = @SuiteId AND SProcType = 'Teardown'

   DECLARE CrsTests CURSOR LOCAL FOR
   SELECT TestId 
   FROM Data.Test 
   WHERE SuiteId = @SuiteId AND SProcType = 'Test'
   ORDER By TestId

   OPEN CrsTests
   FETCH NEXT FROM CrsTests INTO @TestSProcId
   WHILE @@FETCH_STATUS = 0
   BEGIN
   
      BEGIN TRY

         EXEC Internal.RunOneTestInternal
               @TestSessionId    ,
               @TestSProcId      ,
               @SetupSProcId     ,
               @TeardownSProcId  

         IF ( (SELECT COUNT(1) FROM Data.TestLog WHERE TestSessionId = @TestSessionId AND TestId = @TestSProcId AND EntryType IN('P', 'I', 'F', 'E')) = 0 )
         BEGIN
            -- We don't want here to call Assert.Fail because that raises an error. We'll simply insert the error message in TestLog
            INSERT INTO Data.TestLog(TestSessionId, TestId, EntryType, LogMessage) 
            VALUES (@TestSessionId, @TestSProcId, 'F', 'No Assert, Fail, Pass or Ignore was invoked by this test. You must call at least one TST API that performs a validation, records a failure, records a pass or ignores the test (Assert..., Pass, Ignore, Fail, etc.)')
         END

      END TRY
      BEGIN CATCH
         -- RunOneTestInternal should trap all possible errors and handle them
         -- We should not get into this situation. 
         
         -- TODO: can we extract the below string building in a function? 
         SET @ErrorMessage =  'TST Internal Error in RunOneSuiteInternal. Unexpected error: ' +
                              CAST(ERROR_NUMBER() AS varchar) + ', ' + ERROR_MESSAGE() + 
                              ' Procedure: ' + ISNULL(ERROR_PROCEDURE(), 'N/A') + '. Line: ' + CAST(ERROR_LINE() AS varchar)
         EXEC Internal.LogErrorMessage @ErrorMessage

      END CATCH

      -- Update #Tmp_CrtSessionInfo to indicate we are outside of any test stored procedure.
      UPDATE #Tmp_CrtSessionInfo SET TestId = -1, Stage = '-'

      FETCH NEXT FROM CrsTests INTO @TestSProcId
   END

   CLOSE CrsTests
   DEALLOCATE CrsTests

END
GO

-- =======================================================================
-- PROCEDURE: RunTestSessionSetup
-- Runs the test session setup. 
-- Return code:
--    0 - OK. No test session setup procedure was found or it was found, executed and passed. 
--    1 - The test session setup procedure was found, executed and failed. 
-- =======================================================================
CREATE PROCEDURE Internal.RunTestSessionSetup
   @TestSessionId       int               -- Identifies the test session.
AS
BEGIN

   DECLARE @SessionSetupSProcId int

   SELECT @SessionSetupSProcId = TestId FROM Data.Test WHERE TestSessionId = @TestSessionId AND SProcType = 'SetupS'
   IF (@SessionSetupSProcId IS NOT NULL) 
   BEGIN TRY
      UPDATE #Tmp_CrtSessionInfo SET TestId = @SessionSetupSProcId, Stage = 'A'
      EXEC Internal.RunSessionLevelSProc @TestSessionId, @SessionSetupSProcId
   END TRY
   BEGIN CATCH

      DECLARE @ErrorMessage         nvarchar(4000)
      DECLARE @FullSprocName        nvarchar(1000)
      SET @FullSprocName = Internal.SFN_GetFullSprocName(@SessionSetupSProcId)

      -- If this is an error raised by the TST API (like Assert) we don't have to log the error, it was already logged.
      IF (ERROR_MESSAGE() != 'TST RAISERROR {6C57D85A-CE44-49ba-9286-A5227961DF02}') 
      BEGIN
         SET @ErrorMessage =  'An error occured during the execution of the test procedure ''' + @FullSprocName + 
                              '''. Error: ' + CAST(ERROR_NUMBER() AS varchar) + ', ' + ERROR_MESSAGE() + 
                              ' Procedure: ' + ISNULL(ERROR_PROCEDURE(), 'N/A') + '. Line: ' + CAST(ERROR_LINE() AS varchar)
         EXEC Internal.LogErrorMessage @ErrorMessage
      END

      EXEC Internal.LogErrorMessage 'The test session will be aborted. No tests will be run. The execution will continue with the test session teardown.'

      RETURN 1
   END CATCH

   RETURN 0

END
GO

-- =======================================================================
-- PROCEDURE: RunTestSessionTeardown
-- Runs the test session teardown. 
-- Return code:
--    0 - OK. No test session teardown procedure was found or it was found, executed and passed. 
--    1 - The test session teardown procedure was found, executed and failed. 
-- =======================================================================
CREATE PROCEDURE Internal.RunTestSessionTeardown
   @TestSessionId       int               -- Identifies the test session.
AS
BEGIN

   DECLARE @SessionTeardownSProcId int

   SELECT @SessionTeardownSProcId = TestId FROM Data.Test WHERE TestSessionId = @TestSessionId AND SProcType = 'TeardownS'
   IF (@SessionTeardownSProcId IS NOT NULL) 
   BEGIN TRY
      UPDATE #Tmp_CrtSessionInfo SET TestId = @SessionTeardownSProcId, Stage = 'Z'
      EXEC Internal.RunSessionLevelSProc @TestSessionId, @SessionTeardownSProcId
   END TRY
   BEGIN CATCH

      DECLARE @ErrorMessage         nvarchar(4000)
      DECLARE @FullSprocName        nvarchar(1000)
      SET @FullSprocName = Internal.SFN_GetFullSprocName(@SessionTeardownSProcId)

      -- If this is an error raised by the TST API (like Assert) we don't have to log the error, it was already logged.
      IF (ERROR_MESSAGE() != 'TST RAISERROR {6C57D85A-CE44-49ba-9286-A5227961DF02}') 
      BEGIN
         SET @ErrorMessage =  'An error occured during the execution of the test procedure ''' + @FullSprocName + 
                              '''. Error: ' + CAST(ERROR_NUMBER() AS varchar) + ', ' + ERROR_MESSAGE() + 
                              ' Procedure: ' + ISNULL(ERROR_PROCEDURE(), 'N/A') + '. Line: ' + CAST(ERROR_LINE() AS varchar)
         EXEC Internal.LogErrorMessage @ErrorMessage
      END

      RETURN 1
   END CATCH

   RETURN 0

END
GO

-- =======================================================================
-- PROCEDURE: RunTestSession
-- Called by RunSuite or RunTest.
-- Assumes all the data regarding the test session was prepared by 
-- PrepareTestSessionInformation
-- Return code:
--    0 - OK. All appropiate tests were run.
--    1 - Error. Suite not found or no suites were defined.
-- =======================================================================
CREATE PROCEDURE Internal.RunTestSession
   @TestSessionId       int,              -- Identifies the test session.
   @SuiteName           sysname = NULL    -- The suite that must be run. If not specified then 
                                          -- tests in all suites will be run.
AS
BEGIN

   DECLARE @SuiteId                 int
   DECLARE @LogMessage              nvarchar(max)
   DECLARE @CountSuite              int
   DECLARE @TestSessionSetupResult  int
   
   IF @SuiteName IS NOT NULL
   BEGIN
      SELECT @SuiteId = SuiteId FROM Data.Suite WHERE TestSessionId = @TestSessionId AND SuiteName = @SuiteName
      IF @SuiteId IS NULL
      BEGIN
         SET @LogMessage = 'Suite ''' + @SuiteName + ''' not found'
         EXEC Internal.LogErrorMessage @LogMessage
         RETURN 1
      END
   END
   
   EXEC @TestSessionSetupResult = Internal.RunTestSessionSetup @TestSessionId
   IF (@TestSessionSetupResult != 0) GOTO LblBeforeSessionTeardown

   IF @SuiteName IS NOT NULL
   BEGIN
      EXEC Internal.RunOneSuiteInternal @TestSessionId, @SuiteId
   END
   ELSE
   BEGIN

      DECLARE CrsSuites CURSOR LOCAL FOR 
      SELECT SuiteId 
      FROM Data.Suite 
      WHERE TestSessionId = @TestSessionId
      ORDER BY SuiteId

      OPEN CrsSuites
      FETCH NEXT FROM CrsSuites INTO @SuiteId
      WHILE @@FETCH_STATUS = 0
      BEGIN
         EXEC Internal.RunOneSuiteInternal @TestSessionId, @SuiteId
         FETCH NEXT FROM CrsSuites INTO @SuiteId
      END

      CLOSE CrsSuites
      DEALLOCATE CrsSuites
   END

LblBeforeSessionTeardown:

   EXEC Internal.RunTestSessionTeardown @TestSessionId

   RETURN 0
END
GO


-- =======================================================================
-- PROCEDURE: PrintLogEntriesForTest
-- It will print the results for the given test. Called by PrintOneSuiteResults
-- =======================================================================
CREATE PROCEDURE Internal.PrintLogEntriesForTest
   @TestId          int,            -- Identifies the test.
   @ResultsFormat   varchar(10),    -- Indicates if the format in which the results will be printed.
                                    -- See the coments at the begining of the file under section 'Results Format'
   @Verbose         bit             -- If 1 then the output will contain all suites and tests names and all the log entries.
                                    -- If 0 then the output will contain all suites and tests names but only the 
                                    -- log entries indicating failures.
   
AS
BEGIN

   DECLARE @EntryType         char
   DECLARE @LogMessage        nvarchar(max)
   DECLARE @EntryTypeString   varchar(10)

   IF (@Verbose = 1)
   BEGIN
      DECLARE CrsTestResults CURSOR LOCAL FOR
      SELECT Internal.SFN_GetEntryTypeName(EntryType), LogMessage FROM Data.TSTResults
      WHERE TestId = @TestId
      ORDER BY LogEntryId
   END
   ELSE
   BEGIN
      DECLARE CrsTestResults CURSOR LOCAL FOR
      SELECT Internal.SFN_GetEntryTypeName(EntryType), LogMessage FROM Data.TSTResults
      WHERE TestId = @TestId AND EntryType IN ('F', 'E')
      ORDER BY LogEntryId
   END


   OPEN CrsTestResults
   FETCH NEXT FROM CrsTestResults INTO @EntryTypeString, @LogMessage
   WHILE @@FETCH_STATUS = 0
   BEGIN

      IF (@ResultsFormat = 'Text')
      BEGIN
         PRINT REPLICATE(' ', 12) + @EntryTypeString + ': ' + @LogMessage
      END
      ELSE IF (@ResultsFormat = 'XML')
      BEGIN
         PRINT REPLICATE(' ', 10) + '<Log entryType="' + @EntryTypeString + '">' + Internal.SFN_EscapeForXml(@LogMessage) + '</Log>'
      END

      FETCH NEXT FROM CrsTestResults INTO @EntryTypeString, @LogMessage
   END

   CLOSE CrsTestResults
   DEALLOCATE CrsTestResults

END
GO


-- =======================================================================
-- PROCEDURE: PrintOneSuiteResults
-- It will print the results for the given test suite. Called by PrintSuitesResultsForSession
-- =======================================================================
CREATE PROCEDURE Internal.PrintOneSuiteResults 
   @SuiteId          int,              -- Identifies the suite.
   @SuiteTypeId      int,              -- Identifies the type of suite. See Internal.SFN_GetSuiteTypeId.
   @ResultsFormat    varchar(10),      -- Indicates if the format in which the results will be printed.
                                       -- See the coments at the begining of the file under section 'Results Format'
   @Verbose          bit               -- If 1 then the output will contain all suites and tests names and all the log entries.
                                       -- If 0 then the output will contain all suites and tests names but only the 
                                       -- log entries indicating failures.
AS
BEGIN

   DECLARE @TestId               int
   DECLARE @SProcType            varchar(10)
   DECLARE @SProcName            sysname
   DECLARE @TestStatus           nvarchar(10)
   DECLARE @FailOrErrorEntries   int
   DECLARE @IgnoreEntries        int

   DECLARE CrsTestsResults CURSOR LOCAL FOR
   SELECT TestId, SProcType, SProcName FROM Data.TSTResults 
   WHERE SuiteId = @SuiteId
   GROUP BY TestId, SProcType, SProcName
   ORDER BY TestId

   IF (@ResultsFormat = 'XML')
   BEGIN
      -- The session seup and session teardown are handled differently.
      IF(@SuiteTypeId != 0 AND @SuiteTypeId != 3)
      BEGIN
         PRINT REPLICATE(' ', 6) + '<Tests>'
      END
   END

   OPEN CrsTestsResults
   FETCH NEXT FROM CrsTestsResults INTO @TestId, @SProcType, @SProcName
   WHILE @@FETCH_STATUS = 0
   BEGIN

      SET @FailOrErrorEntries = Internal.SFN_GetCountOfFailOrErrorEntriesForTest(@TestId)
      SET @IgnoreEntries = Internal.SFN_GetCountOfIgnoreEntriesForTest(@TestId)

      IF(@FailOrErrorEntries != 0) SET @TestStatus = 'Failed'
      ELSE IF (@IgnoreEntries != 0) SET @TestStatus = 'Ignored'
      ELSE SET @TestStatus = 'Passed'

      IF (@ResultsFormat = 'Text')
      BEGIN
         IF (@SProcType = 'SetupS')
         BEGIN
            PRINT REPLICATE(' ', 4) + 'SESSION SETUP: ' + @TestStatus
         END
         ELSE IF (@SProcType = 'TeardownS')
         BEGIN
            PRINT REPLICATE(' ', 4) + 'SESSION TEARDOWN: ' + @TestStatus
         END
         ELSE
         BEGIN
            PRINT REPLICATE(' ', 8) + 'Test: ' + @SProcName + '. ' + @TestStatus
         END
      END
      ELSE IF (@ResultsFormat = 'XML')
      BEGIN

         IF (@SProcType = 'SetupS')
         BEGIN
            PRINT REPLICATE(' ', 4) + '<SessionSetup status="' + @TestStatus + '">'
         END
         ELSE IF (@SProcType = 'TeardownS')
         BEGIN
            PRINT REPLICATE(' ', 4) + '<SessionTeardown status="' + @TestStatus + '">'
         END
         ELSE
         BEGIN
            PRINT REPLICATE(' ', 8) + '<Test' + 
               ' name="' + @SProcName + '"' +
               ' status="' + @TestStatus + '"' +
               ' >'
         END
      END

      EXEC Internal.PrintLogEntriesForTest @TestId, @ResultsFormat, @Verbose

      IF (@ResultsFormat = 'XML')
      BEGIN
         IF (@SProcType = 'SetupS')
         BEGIN
            PRINT REPLICATE(' ', 4) + '</SessionSetup>'
         END
         ELSE IF (@SProcType = 'TeardownS')
         BEGIN
            PRINT REPLICATE(' ', 4) + '</SessionTeardown>'
         END
         ELSE
         BEGIN
            PRINT REPLICATE(' ', 8) + '</Test>'
         END
      END

      FETCH NEXT FROM CrsTestsResults INTO @TestId, @SProcType, @SProcName
   END

   CLOSE CrsTestsResults
   DEALLOCATE CrsTestsResults
   
   IF (@ResultsFormat = 'XML')
   BEGIN
      -- The session seup and session teardown are handled differently.
      IF(@SuiteTypeId != 0 AND @SuiteTypeId != 3)
      BEGIN
         PRINT REPLICATE(' ', 6) + '</Tests>'
      END
   END

END
GO


-- =======================================================================
-- PROCEDURE: CleanSessionData
-- It will delete all the transitory data that refers to the test session 
-- given by @TestSessionId
-- =======================================================================
CREATE PROCEDURE Internal.CleanSessionData
   @TestSessionId   int
AS
BEGIN

   DELETE FROM Data.TSTParameters   WHERE TestSessionId=@TestSessionId
   DELETE FROM Data.SystemErrorLog  WHERE TestSessionId=@TestSessionId
   DELETE FROM Data.TestLog         WHERE TestSessionId=@TestSessionId

   DELETE Data.Test
   FROM Data.Test
   WHERE Test.TestSessionId=@TestSessionId

   DELETE FROM Data.Suite WHERE TestSessionId=@TestSessionId

   DELETE FROM Data.TestSession WHERE TestSessionId=@TestSessionId

END
GO

-- =======================================================================
-- PROCEDURE: PrintStatusForSession
-- See the coments at the begining of the file under section 'Results Format'
-- This procedure will print the results when the @ResultsFormat = 'Batch'
-- =======================================================================
CREATE PROCEDURE Internal.PrintStatusForSession
   @TestSessionId    int      -- Identifies the test session.
AS
BEGIN

   DECLARE @TestSessionStatus bit
   SET @TestSessionStatus = Internal.SFN_GetSessionStatus(@TestSessionId) 

   IF (@TestSessionStatus = 1) PRINT 'TST Status: Passed'
   ELSE PRINT 'TST Status: Failed'

END
GO

-- =======================================================================
-- PROCEDURE: PrintHeaderForSession
-- It will print the first lines in the result screen orin the XML file
-- =======================================================================
CREATE PROCEDURE Internal.PrintHeaderForSession
   @TestSessionId    int,         -- Identifies the test session.
   @ResultsFormat    varchar(10), -- Indicates if the format in which the results will be printed.
                                  -- See the coments at the begining of the file under section 'Results Format'
   @NoTimestamp      bit = 0      -- Indicates that no timestamp or duration info should be printed in results output
AS
BEGIN

   DECLARE @TestSessionStart           datetime
   DECLARE @TestSessionFinish          datetime
   DECLARE @TestSessionStatus          bit
   DECLARE @TestSessionStatusString    varchar(16)
   DECLARE @ResultMessage              nvarchar(1000)

   SELECT 
      @TestSessionStart   = TestSessionStart, 
      @TestSessionFinish  = TestSessionFinish
   FROM Data.TestSession
   WHERE TestSessionId = @TestSessionId
   
   SET @TestSessionStatus = Internal.SFN_GetSessionStatus(@TestSessionId) 

   IF (@TestSessionStatus = 1) SET @TestSessionStatusString = 'Passed'
   SET @TestSessionStatusString = 'Failed'

   IF (@ResultsFormat = 'XML')
   BEGIN
      IF (@NoTimestamp=0)
      BEGIN
         SET @ResultMessage = '<TST' + 
            ' status="' + @TestSessionStatusString + '"' + 
            ' testSessionId="' + CAST(@TestSessionId AS varchar) + '"' + 
            ' start="' + CONVERT(nvarchar(20), @TestSessionStart, 108) + '"' + 
            ' finish="' + CONVERT(nvarchar(20), @TestSessionFinish, 108) + '"' + 
            ' duration="' + CONVERT(nvarchar(10), DATEDIFF(ms, @TestSessionStart, @TestSessionFinish)) + '"' + 
            ' >'
      END
      ELSE
      BEGIN
         SET @ResultMessage = '<TST' + 
            ' status="' + @TestSessionStatusString + '"' + 
            ' >'
     END
     PRINT @ResultMessage 
   END

END
GO


-- =======================================================================
-- PROCEDURE: PrintResultsSummaryForSession
-- It will print the last lines in the result screen - those that 
-- have the summary of the test session given by @TestSessionId.
-- =======================================================================
CREATE PROCEDURE Internal.PrintResultsSummaryForSession
   @TestSessionId    int,         -- Identifies the test session.
   @ResultsFormat    varchar(10), -- Indicates if the format in which the results will be printed.
                                  -- See the coments at the begining of the file under section 'Results Format'
   @NoTimestamp      bit = 0      -- Indicates that no timestamp or duration info should be printed in results output
AS
BEGIN

   DECLARE @TestSessionStart              datetime
   DECLARE @TestSessionFinish             datetime
   DECLARE @TotalSuiteCount               int
   DECLARE @TotalTestCount                int
   DECLARE @TotalPassedCount              int
   DECLARE @TotalIgnoredCount             int
   DECLARE @TotalFailedCount              int

   SELECT 
      @TestSessionStart   = TestSessionStart, 
      @TestSessionFinish  = TestSessionFinish
   FROM Data.TestSession
   WHERE TestSessionId = @TestSessionId
   
   SET @TotalSuiteCount  = Internal.SFN_GetCountOfSuitesInSession(@TestSessionId) 
   SET @TotalTestCount   = Internal.SFN_GetCountOfTestsInSession(@TestSessionId) 
   SET @TotalPassedCount = Internal.SFN_GetCountOfPassedTestsInSession(@TestSessionId) 
   SET @TotalIgnoredCount= Internal.SFN_GetCountOfIgnoredTestsInSession(@TestSessionId) 
   SET @TotalFailedCount = Internal.SFN_GetCountOfFailedTestsInSession(@TestSessionId) 
   
   IF (@ResultsFormat = 'Text')
   BEGIN
      IF (@NoTimestamp = 0)
      BEGIN
         PRINT 'Start: ' + CONVERT(nvarchar(20), @TestSessionStart, 108) + '. Finish: ' + CONVERT(nvarchar(20), @TestSessionFinish, 108) + '. Duration: ' + CONVERT(nvarchar(10), DATEDIFF(ms, @TestSessionStart, @TestSessionFinish)) + ' miliseconds.'
      END

      PRINT 'Total suites: ' + CAST(@TotalSuiteCount as varchar) + '. Total tests: ' + CAST(@TotalTestCount AS varchar) + '. Test passed: ' + CAST(@TotalPassedCount AS varchar) + '. Test ignored: ' + CAST(@TotalIgnoredCount AS varchar) + '. Test failed: ' + CAST(@TotalFailedCount AS varchar) + '.'
   END

END
GO

-- =======================================================================
-- PROCEDURE: PrintSystemErrorsForSession
-- It will print all the system errors that occured in the test session 
-- given by @TestSessionId
-- =======================================================================
CREATE PROCEDURE Internal.PrintSystemErrorsForSession
   @TestSessionId    int,           -- Identifies the test session.
   @ResultsFormat    varchar(10)    -- Indicates if the format in which the results will be printed.
                                    -- See the coments at the begining of the file under section 'Results Format'
AS
BEGIN
   
   DECLARE @SystemError       nvarchar(1000)

   DECLARE CrsSystemErrors CURSOR LOCAL FOR
   SELECT LogMessage FROM Data.SystemErrorLog WHERE TestSessionId = @TestSessionId ORDER BY CreatedTime

   IF (@ResultsFormat = 'XML')
   BEGIN
      PRINT REPLICATE(' ', 2) + '<SystemErrors>'
   END
      
   OPEN CrsSystemErrors
   FETCH NEXT FROM CrsSystemErrors INTO @SystemError
   WHILE @@FETCH_STATUS = 0
   BEGIN

      IF (@ResultsFormat = 'Text')
      BEGIN
         PRINT REPLICATE(' ', 4) + 'Error: ' + @SystemError
      END
      ELSE IF (@ResultsFormat = 'XML')
      BEGIN
         PRINT REPLICATE(' ', 4) + '<SystemError>' + Internal.SFN_EscapeForXml(@SystemError) + '</SystemError>'
      END
      
      FETCH NEXT FROM CrsSystemErrors INTO @SystemError
   END

   CLOSE CrsSystemErrors
   DEALLOCATE CrsSystemErrors

   IF (@ResultsFormat = 'XML')
   BEGIN
      PRINT REPLICATE(' ', 2) + '</SystemErrors>'
   END

END
GO

-- =======================================================================
-- PROCEDURE: PrintSuitesResultsForSession
-- It will print all the results of the current test session. 
-- =======================================================================
CREATE PROCEDURE Internal.PrintSuitesResultsForSession
   @TestSessionId   int,            -- Identifies the test session.
   @ResultsFormat   varchar(10),    -- Indicates if the format in which the results will be printed.
                                    -- See the coments at the begining of the file under section 'Results Format'
   @Verbose          bit            -- If 1 then the output will contain all suites and tests names and all the log entries.
                                    -- If 0 then the output will contain all suites and tests names but only the 
                                    -- log entries indicating failures.
AS
BEGIN

   DECLARE @SuitesNodeWasCreated          bit
   DECLARE @SuitesNodeWasClosed           bit
   DECLARE @SuiteId                       int
   DECLARE @SuiteTypeId                   int
   DECLARE @SuiteName                     sysname
   DECLARE @CountOfPassedTestInSuite      int
   DECLARE @CountOfIgnoredTestInSuite     int
   DECLARE @CountOfFailedTestInSuite      int
   DECLARE @CountOfTestInSuite            int

   DECLARE CrsSuiteResults CURSOR LOCAL FOR
   SELECT SuiteId, Internal.SFN_GetSuiteTypeId(SuiteName), SuiteName FROM Data.TSTResults 
   WHERE TestSessionId = @TestSessionId
   GROUP BY SuiteId, SuiteName
   ORDER BY Internal.SFN_GetSuiteTypeId(SuiteName), SuiteName

   SET @SuitesNodeWasCreated  = 0
   SET @SuitesNodeWasClosed   = 0

   OPEN CrsSuiteResults
   FETCH NEXT FROM CrsSuiteResults INTO @SuiteId, @SuiteTypeId, @SuiteName
   WHILE @@FETCH_STATUS = 0
   BEGIN

      IF (@ResultsFormat = 'XML')
      BEGIN
         IF (@SuitesNodeWasCreated = 0 AND @SuiteTypeId != 0 AND @SuiteTypeId != 3)
         BEGIN
            PRINT REPLICATE(' ', 2) + '<Suites>'
            SET @SuitesNodeWasCreated = 1
         END

         IF (@SuitesNodeWasCreated = 1 AND @SuitesNodeWasClosed = 0 AND @SuiteTypeId = 3)
         BEGIN
            PRINT REPLICATE(' ', 2) + '</Suites>'
            SET @SuitesNodeWasClosed  = 1
         END
      END

      SET @CountOfTestInSuite = Internal.SFN_GetCountOfTestsInSuite(@SuiteId) 
      SET @CountOfFailedTestInSuite = Internal.SFN_GetCountOfFailedTestsInSuite(@SuiteId)
      SET @CountOfIgnoredTestInSuite = Internal.SFN_GetCountOfIgnoredTestsInSuite(@SuiteId)
      SET @CountOfPassedTestInSuite = Internal.SFN_GetCountOfPassedTestsInSuite(@SuiteId)
      
      IF (@ResultsFormat = 'Text')
      BEGIN
         -- The "session setup suite" and "session teardown suite" are not really suites.
         IF (@SuiteTypeId != 0 AND @SuiteTypeId != 3)
         BEGIN
            PRINT REPLICATE(' ', 4) + 'Suite: ' + ISNULL(@SuiteName, 'Anonymous') + '. Tests: ' + CAST(@CountOfTestInSuite as nvarchar(10)) + '. Passed: ' + CAST(@CountOfPassedTestInSuite as nvarchar(10)) + '. Ignored: ' + CAST(@CountOfIgnoredTestInSuite as nvarchar(10)) + '. Failed: ' + CAST(@CountOfFailedTestInSuite as nvarchar(10))
         END
      END
      ELSE IF (@ResultsFormat = 'XML')
      BEGIN
         -- The "session setup suite" and "session teardown suite" are not really suites.
         IF (@SuiteTypeId != 0 AND @SuiteTypeId != 3)
         BEGIN
            PRINT REPLICATE(' ', 4) + '<Suite' + 
               ' suiteName="' + ISNULL(@SuiteName, 'Anonymous') + '"' + 
               ' testsCount="' + CAST(@CountOfTestInSuite as nvarchar(10)) + '"' + 
               ' passedCount="' + CAST(@CountOfPassedTestInSuite as nvarchar(10)) + '"' + 
               ' ignoredCount="' + CAST(@CountOfIgnoredTestInSuite as nvarchar(10)) + '"' + 
               ' failedCount="' + CAST(@CountOfFailedTestInSuite as nvarchar(10)) + '"' + 
               ' >'
         END
      END

      EXEC Internal.PrintOneSuiteResults @SuiteId, @SuiteTypeId, @ResultsFormat, @Verbose

      IF (@ResultsFormat = 'XML')
      BEGIN
         -- The "session setup suite" and "session teardown suite" are not really suites.
         IF (@SuiteTypeId != 0 AND @SuiteTypeId != 3)
         BEGIN
            PRINT REPLICATE(' ', 4) + '</Suite>'
         END
      END

      FETCH NEXT FROM CrsSuiteResults INTO @SuiteId, @SuiteTypeId, @SuiteName
   END

   CLOSE CrsSuiteResults
   DEALLOCATE CrsSuiteResults

   IF (@ResultsFormat = 'XML')
   BEGIN
      IF (@SuitesNodeWasCreated = 1 AND @SuitesNodeWasClosed = 0)
      BEGIN
         PRINT REPLICATE(' ', 2) + '</Suites>'
         SET @SuitesNodeWasClosed  = 1
      END
   END

END
GO

-- =======================================================================
-- PROCEDURE: PrintResults
-- It will print all the results of the current test session. 
-- =======================================================================
CREATE PROCEDURE Utils.PrintResults
   @TestSessionId    int,         -- Identifies the test session.
   @ResultsFormat    varchar(10), -- Indicates if the format in which the results will be printed.
                                  -- See the coments at the begining of the file under section 'Results Format'
   @NoTimestamp      bit = 0,     -- Indicates that no timestamp or duration info should be printed in results output
   @Verbose          bit = 0      -- If 1 then the output will contain all suites and tests names and all the log entries.
                                  -- If 0 then the output will contain all suites and tests names but only the 
                                  -- log entries indicating failures.
AS
BEGIN
   
   IF (      @ResultsFormat != 'Text'
         AND @ResultsFormat != 'XML'
         AND @ResultsFormat != 'Batch'
         AND @ResultsFormat != 'None' )
   BEGIN
      RAISERROR('Invalid call to RunSuite. @TestDatabaseName cannot be NULL.', 16, 1)
      RETURN 1
   END

   IF (@ResultsFormat = 'None') RETURN 0

   IF (@ResultsFormat = 'Batch' OR @ResultsFormat = 'Text' ) PRINT ''
   
   IF (@ResultsFormat = 'Batch')
   BEGIN
      PRINT 'TST TestSessionId: ' + CAST(@TestSessionId as varchar)

      -- For the rest of the print process 'Batch' mode is the same as 'Text' mode
      SET @ResultsFormat = 'Text'
   END
   
   IF (@ResultsFormat = 'XML')
   BEGIN
      PRINT '<?xml version="1.0" encoding="utf-8" ?> '
   END

   EXEC Internal.PrintHeaderForSession         @TestSessionId, @ResultsFormat, @NoTimestamp
   EXEC Internal.PrintSystemErrorsForSession   @TestSessionId, @ResultsFormat
   EXEC Internal.PrintSuitesResultsForSession  @TestSessionId, @ResultsFormat, @Verbose

   IF (@ResultsFormat = 'Batch' OR @ResultsFormat = 'Text' ) PRINT ''
   EXEC Internal.PrintResultsSummaryForSession @TestSessionId, @ResultsFormat, @NoTimestamp

   IF (@ResultsFormat = 'Text')
   BEGIN
      PRINT ''
      EXEC Internal.PrintStatusForSession  @TestSessionId
      PRINT ''
   END
   ELSE
   IF (@ResultsFormat = 'XML')
   BEGIN
      PRINT '</TST>'
   END

   RETURN 0
END
GO

-- =======================================================================
-- PROCEDURE: PostTestRun
-- Execute the optional post test run steps: print results and 
-- clean of temporary data.
-- =======================================================================
CREATE PROCEDURE Internal.PostTestRun
   @TestSessionId          int,              -- Identifies the test session.
   @ResultsFormat          varchar(10),      -- Indicates if the format in which the results will be printed.
                                             -- See the coments at the begining of the file under section 'Results Format'
   @NoTimestamp            bit,              -- Indicates that no timestamp or duration info should be printed in results output
   @Verbose                bit,              -- If 1 then the output will contain all suites and tests names and all the log entries.
                                             -- If 0 then the output will contain all suites and tests names but only the 
                                             -- log entries indicating failures.
   @CleanTemporaryData     bit               -- Indicates if the temporary tables should be cleaned at the end.
AS
BEGIN

   EXEC Utils.PrintResults @TestSessionId, @ResultsFormat, @NoTimestamp, @Verbose
   IF (@CleanTemporaryData = 1)  EXEC Internal.CleanSessionData  @TestSessionId
   
END
GO


-- =======================================================================
-- PROCEDURE: BasicTempTableValidation
-- Makes sure that #ExpectedResult and #ActualResult are created and have 
-- the same number of entries
-- Return code:
--    0 - OK. #ExpectedResult and #ActualResult are created and have 
--            the same number of entries.
--    1 - An error was detected. An error was raised.
-- =======================================================================
CREATE PROCEDURE Internal.BasicTempTableValidation
   @ContextMessage      nvarchar(1000),
   @ExpectedRowCount    int OUT        -- At return will contain the number of rows in #ExpectedResult
AS
BEGIN

   DECLARE @ActualRowCount    int
   DECLARE @Message           nvarchar(4000)

   IF (object_id('tempdb..#ExpectedResult') IS NULL) 
   BEGIN
      SET @Message = 'Assert.TableEquals failed. [' + @ContextMessage + '] #ExpectedResult table was not created.' 
      EXEC Assert.Fail @Message
      RETURN 1
   END
   
   IF (object_id('tempdb..#ActualResult') IS NULL) 
   BEGIN
      SET @Message = 'Assert.TableEquals failed. [' + @ContextMessage + '] #ActualResult table was not created.' 
      EXEC Assert.Fail @Message
      RETURN 1
   END

   SELECT @ExpectedRowCount = COUNT(*) FROM #ExpectedResult
   SELECT @ActualRowCount   = COUNT(*) FROM #ActualResult

   IF (@ExpectedRowCount != @ActualRowCount )
   BEGIN
      SET @Message = 'Assert.TableEquals failed. [' + @ContextMessage + '] Expected row count=' + CAST(@ExpectedRowCount as varchar) + '. Actual row count=' + CAST(@ActualRowCount as varchar) 
      EXEC Assert.Fail @Message
      RETURN 1
   END
   
   RETURN 0

END
GO


-- =======================================================================
-- PROCEDURE: CollectTempTablesSchema
-- Collects schema information about #ExpectedResult and #ActualResult 
-- in #SchemaInfoExpectedResults and #SchemaInfoActualResults
-- =======================================================================
CREATE PROCEDURE Internal.CollectTempTablesSchema
AS
BEGIN

   INSERT INTO #SchemaInfoExpectedResults
   SELECT 
      SysColumns.name                     AS ColumnName,
      SysTypes.name                       AS DataTypeName,
      SysColumns.max_length               AS MaxLength,
      SysColumns.precision                AS ColumnPrecision,
      SysColumns.scale                    AS ColumnScale,
      ISNULL(PKColumns.IsPrimaryKey, 0)   AS IsPrimaryKey,
      CASE WHEN IgnoredColumns.ColumnName IS NULL THEN 0 ELSE 1 END AS IsIgnored,
      PKColumns.PkOrdinal                 AS PkOrdinal,
      SysColumns.collation_name           AS ColumnCollationName
   FROM tempdb.sys.columns AS SysColumns 
   INNER JOIN tempdb.sys.types AS SysTypes ON 
      SysTypes.user_type_id = SysColumns.user_type_id 
   LEFT OUTER JOIN (
         SELECT 
            SysColumns.name               AS PKColumnName,
            SysIndexes.is_primary_key     AS IsPrimaryKey,
            SysIndexColumns.key_ordinal   AS PkOrdinal
         FROM tempdb.sys.columns AS SysColumns 
         INNER JOIN tempdb.sys.indexes AS SysIndexes ON 
            SysIndexes.object_id = SysColumns.object_id 
         INNER JOIN tempdb.sys.index_columns AS SysIndexColumns ON 
            SysIndexColumns.object_id = SysColumns.object_id 
            AND SysIndexColumns.column_id = SysColumns.column_id
            AND SysIndexColumns.index_id = SysIndexes.index_id
         WHERE 
            SysColumns.object_id = object_id('tempdb..#ExpectedResult')
            AND SysIndexes.is_primary_key = 1
      ) AS PKColumns ON SysColumns.name = PKColumns.PKColumnName
   LEFT OUTER JOIN #IgnoredColumns AS IgnoredColumns ON IgnoredColumns.ColumnName = SysColumns.name
   WHERE 
      SysColumns.object_id = object_id('tempdb..#ExpectedResult')

   INSERT INTO #SchemaInfoActualResults
   SELECT 
      SysColumns.name                     AS ColumnName,
      SysTypes.name                       AS DataTypeName,
      SysColumns.max_length               AS MaxLength,
      SysColumns.precision                AS ColumnPrecision,
      SysColumns.scale                    AS ColumnScale,
      ISNULL(PKColumns.IsPrimaryKey, 0)   AS IsPrimaryKey,
      CASE WHEN IgnoredColumns.ColumnName IS NULL THEN 0 ELSE 1 END AS IsIgnored,
      PKColumns.PkOrdinal                 AS PkOrdinal,
      SysColumns.collation_name           AS ColumnCollationName
   FROM tempdb.sys.columns AS SysColumns 
   INNER JOIN tempdb.sys.types AS SysTypes ON 
      SysTypes.user_type_id = SysColumns.user_type_id 
   LEFT OUTER JOIN (
         SELECT 
            SysColumns.name               AS PKColumnName,
            SysIndexes.is_primary_key     AS IsPrimaryKey,
            SysIndexColumns.key_ordinal   AS PkOrdinal
         FROM tempdb.sys.columns AS SysColumns 
         INNER JOIN tempdb.sys.indexes AS SysIndexes ON 
            SysIndexes.object_id = SysColumns.object_id 
         INNER JOIN tempdb.sys.index_columns AS SysIndexColumns ON 
            SysIndexColumns.object_id = SysColumns.object_id 
            AND SysIndexColumns.column_id = SysColumns.column_id
            AND SysIndexColumns.index_id = SysIndexes.index_id
         WHERE 
            SysColumns.object_id = object_id('tempdb..#ActualResult')
            AND SysIndexes.is_primary_key = 1
      ) AS PKColumns ON SysColumns.name = PKColumns.PKColumnName
   LEFT OUTER JOIN #IgnoredColumns AS IgnoredColumns ON IgnoredColumns.ColumnName = SysColumns.name
   WHERE 
      SysColumns.object_id = object_id('tempdb..#ActualResult')

END
GO


-- =======================================================================
-- PROCEDURE: ValidateTempTablesSchema
-- Validates that #ExpectedResult and #ActualResult have the same schema 
-- and that all columns have types that can be handled by the comparison
-- procedure.
-- Asumes that #SchemaInfoExpectedResults and #SchemaInfoActualResults
-- are already created and contain the appropiate data.
-- At return: 
--    - If the validation passed then @SchemaError will be NULL
--    - If the validation did not passed then @SchemaError will contain an 
--      error message.
-- =======================================================================
CREATE PROCEDURE Internal.ValidateTempTablesSchema
   @SchemaError       nvarchar(1000) OUT 
AS
BEGIN

   DECLARE @ColumnName                 sysname
   DECLARE @ColumnDataType             sysname
   DECLARE @ColumnTypeInExpected       sysname
   DECLARE @ColumnTypeInActual         sysname
   DECLARE @ColumnLengthInExpected     int
   DECLARE @ColumnLengthInActual       int
   DECLARE @ColumnCollationInExpected  sysname
   DECLARE @ColumnCollationInActual    sysname
   
   
   -- Make sure that we do not have duplicated entries in #IgnoredColumns 
   SET @ColumnName = NULL
   SELECT TOP 1 @ColumnName = ColumnName FROM #IgnoredColumns GROUP BY ColumnName HAVING COUNT(ColumnName) > 1
   IF (@ColumnName IS NOT NULL)
   BEGIN
      SET @SchemaError = 'Column ''' + @ColumnName + ''' is specified more than once in the list of ignored columns.'
      RETURN 
   END

   -- Make sure that all the columns indicated in #IgnoredColumns exist in at least one of the tables #ActualResult or #ExpectedResult
   SET @ColumnName = NULL
   SELECT TOP 1 @ColumnName = ColumnName 
   FROM #IgnoredColumns
   WHERE ColumnName NOT IN (
         SELECT ISNULL(#SchemaInfoExpectedResults.ColumnName, #SchemaInfoActualResults.ColumnName) AS ColumnName
         FROM #SchemaInfoExpectedResults 
         FULL OUTER JOIN #SchemaInfoActualResults ON #SchemaInfoExpectedResults.ColumnName = #SchemaInfoActualResults.ColumnName
      )

   IF (@ColumnName IS NOT NULL)
   BEGIN
      SET @SchemaError = 'Column ''' + @ColumnName + ''' from the list of ignored columns does not exist in any of #ActualResult or #ExpectedResult.'
      RETURN 
   END
   
   -- Make sure that no primary key is in #IgnoredColumns.
   -- We'll only look at the primary key in #SchemaInfoExpectedResults. No need to look at the primary key in #SchemaInfoActualResults
   -- since we check that they have the exact same columns in the primary key.
   SET @ColumnName = NULL
   SELECT TOP 1 @ColumnName = ColumnName FROM #SchemaInfoExpectedResults WHERE IsPrimaryKey = 1 AND IsIgnored = 1
   IF (@ColumnName IS NOT NULL)
   BEGIN
      SET @SchemaError = 'Column ''' + @ColumnName + ''' that is specified in the list of ignored columns cannot be ignored because is part of the primary key in #ActualResult and #ExpectedResult.'
      RETURN 
   END

   SET @ColumnName = NULL
   SELECT TOP 1 @ColumnName = ColumnName FROM #SchemaInfoExpectedResults WHERE IsIgnored = 0 AND ColumnName NOT IN (SELECT ColumnName FROM #SchemaInfoActualResults) 
   IF (@ColumnName IS NOT NULL)
   BEGIN
      SET @SchemaError = '#ExpectedResult and #ActualResult do not have the same schema. Column ''' + @ColumnName + ''' in #ExpectedResult but not in #ActualResult'
      RETURN 
   END

   SELECT TOP 1 @ColumnName = ColumnName FROM #SchemaInfoActualResults  WHERE IsIgnored = 0 AND ColumnName NOT IN (SELECT ColumnName FROM #SchemaInfoExpectedResults )
   IF (@ColumnName IS NOT NULL)
   BEGIN
      SET @SchemaError = '#ExpectedResult and #ActualResult do not have the same schema. Column ''' + @ColumnName + ''' in #ActualResult but not in #ExpectedResult'
      RETURN 
   END
   
   -- At this point, we confirmed that the two tables have the same columns. We will check the column types
   SELECT TOP 1 
      @ColumnName             = #SchemaInfoExpectedResults.ColumnName,
      @ColumnTypeInExpected   = ISNULL(#SchemaInfoExpectedResults.DataTypeName, '?'),
      @ColumnTypeInActual     = ISNULL(#SchemaInfoActualResults.DataTypeName, '?')
   FROM #SchemaInfoExpectedResults
   INNER JOIN #SchemaInfoActualResults ON #SchemaInfoActualResults.ColumnName = #SchemaInfoExpectedResults.ColumnName
   WHERE ISNULL(#SchemaInfoExpectedResults.DataTypeName, '?') != ISNULL(#SchemaInfoActualResults.DataTypeName, '?')

   IF (@ColumnName IS NOT NULL)
   BEGIN
      SET @SchemaError = '#ExpectedResult and #ActualResult do not have the same schema. Column #ExpectedResult.' + @ColumnName + ' has type ' + @ColumnTypeInExpected + '. #ActualResult.' + @ColumnName +' has type ' + @ColumnTypeInActual
      RETURN 
   END
   
   -- Columns in the two tables have to have the same max length.
   SELECT TOP 1 
      @ColumnName             = #SchemaInfoExpectedResults.ColumnName,
      @ColumnLengthInExpected = ISNULL(#SchemaInfoExpectedResults.MaxLength, 0),
      @ColumnLengthInActual   = ISNULL(#SchemaInfoActualResults.MaxLength, 0)
   FROM #SchemaInfoExpectedResults
   INNER JOIN #SchemaInfoActualResults ON #SchemaInfoActualResults.ColumnName = #SchemaInfoExpectedResults.ColumnName
   WHERE ISNULL(#SchemaInfoExpectedResults.MaxLength, 0) != ISNULL(#SchemaInfoActualResults.MaxLength, 0)

   IF (@ColumnName IS NOT NULL)
   BEGIN
      SET @SchemaError = '#ExpectedResult and #ActualResult do not have the same schema. Column #ExpectedResult.' + @ColumnName + ' has length ' + CAST(@ColumnLengthInExpected AS varchar) + '. #ActualResult.' + @ColumnName +' has length ' + CAST(@ColumnLengthInActual AS varchar)
      RETURN 
   END

   -- Columns in the two tables have to have the same collation.
   SELECT TOP 1 
      @ColumnName                = #SchemaInfoExpectedResults.ColumnName,
      @ColumnCollationInExpected = ISNULL(#SchemaInfoExpectedResults.ColumnCollationName, 'no collation'),
      @ColumnCollationInActual   = ISNULL(#SchemaInfoActualResults.ColumnCollationName, 'no collation')
   FROM #SchemaInfoExpectedResults
   INNER JOIN #SchemaInfoActualResults ON #SchemaInfoActualResults.ColumnName = #SchemaInfoExpectedResults.ColumnName
   WHERE ISNULL(#SchemaInfoExpectedResults.ColumnCollationName, 'no collation') != ISNULL(#SchemaInfoActualResults.ColumnCollationName, 'no collation')

   IF (@ColumnName IS NOT NULL)
   BEGIN
      SET @SchemaError = 
            '#ExpectedResult and #ActualResult do not have the same schema. Column #ExpectedResult.' + 
            @ColumnName + ' has collation ' + @ColumnCollationInExpected + '. #ActualResult.' + 
            @ColumnName + ' has collation ' + @ColumnCollationInActual
      RETURN 
   END
   
   -- Make sure that all columns have a valid data type 
   SELECT TOP 1 
      @ColumnName = #SchemaInfoExpectedResults.ColumnName, 
      @ColumnDataType = #SchemaInfoExpectedResults.DataTypeName
   FROM #SchemaInfoExpectedResults
   INNER JOIN #SchemaInfoActualResults ON #SchemaInfoActualResults.ColumnName = #SchemaInfoExpectedResults.ColumnName
   WHERE Internal.SFN_ColumnDataTypeIsValid(#SchemaInfoExpectedResults.DataTypeName) = 0
   AND #SchemaInfoExpectedResults.IsIgnored = 0
   IF (@ColumnName IS NOT NULL)
   BEGIN
      SET @SchemaError = 'Column ' + @ColumnName + ' has a type (''' + @ColumnDataType + ''') that cannot be processed by Assert.TableEquals. To ignore this column use the @IgnoredColumns parameter of Assert.TableEquals.'
      RETURN 
   END

   -- We will check that we have a PK
   IF NOT EXISTS (SELECT ColumnName FROM #SchemaInfoExpectedResults WHERE #SchemaInfoExpectedResults.IsPrimaryKey = 1)
   BEGIN
      SET @SchemaError = '#ExpectedResult and #ActualResult must have a primary key defined'
      RETURN 
   END

   -- We will check that the PK columns are the same and in the same order
   SELECT TOP 1 @ColumnName = #SchemaInfoExpectedResults.ColumnName
   FROM #SchemaInfoExpectedResults
   INNER JOIN #SchemaInfoActualResults ON #SchemaInfoActualResults.ColumnName = #SchemaInfoExpectedResults.ColumnName
   WHERE 
      #SchemaInfoExpectedResults.IsPrimaryKey != #SchemaInfoActualResults.IsPrimaryKey
      OR ISNULL(#SchemaInfoExpectedResults.PkOrdinal, -1) != ISNULL(#SchemaInfoActualResults.PkOrdinal, -1)

   IF (@ColumnName IS NOT NULL)
   BEGIN
      SET @SchemaError = 'The primary keys in #ExpectedResult and #ActualResult are not the same'
      RETURN 
   END

   SET @SchemaError = NULL
   RETURN

END
GO

-- =======================================================================
-- FUNCTION : SFN_ColumnDataTypeIsValid
-- Returns 1 if the data type given by @DataTypeName can be 
--           processed by Assert.TableEquals
-- Returns 1 if the data type given by @DataTypeName cannot be 
--           processed by Assert.TableEquals
-- =======================================================================
CREATE FUNCTION Internal.SFN_ColumnDataTypeIsValid(@DataTypeName nvarchar(128)) RETURNS bit
AS
BEGIN

   IF (@DataTypeName = 'bigint'           ) RETURN 1
   IF (@DataTypeName = 'int'              ) RETURN 1
   IF (@DataTypeName = 'smallint'         ) RETURN 1
   IF (@DataTypeName = 'tinyint'          ) RETURN 1
   IF (@DataTypeName = 'money'            ) RETURN 1
   IF (@DataTypeName = 'smallmoney'       ) RETURN 1
   IF (@DataTypeName = 'bit'              ) RETURN 1
   IF (@DataTypeName = 'decimal'          ) RETURN 1
   IF (@DataTypeName = 'numeric'          ) RETURN 1
   IF (@DataTypeName = 'float'            ) RETURN 1
   IF (@DataTypeName = 'real'             ) RETURN 1
   IF (@DataTypeName = 'datetime'         ) RETURN 1
   IF (@DataTypeName = 'smalldatetime'    ) RETURN 1
   IF (@DataTypeName = 'char'             ) RETURN 1
   IF (@DataTypeName = 'text'             ) RETURN 0
   IF (@DataTypeName = 'varchar'          ) RETURN 1
   IF (@DataTypeName = 'nchar'            ) RETURN 1
   IF (@DataTypeName = 'ntext'            ) RETURN 0
   IF (@DataTypeName = 'nvarchar'         ) RETURN 1
   IF (@DataTypeName = 'binary'           ) RETURN 1
   IF (@DataTypeName = 'varbinary'        ) RETURN 1
   IF (@DataTypeName = 'image'            ) RETURN 0
   IF (@DataTypeName = 'cursor'           ) RETURN 0
   IF (@DataTypeName = 'timestamp'        ) RETURN 0
   IF (@DataTypeName = 'sql_variant'      ) RETURN 1
   IF (@DataTypeName = 'uniqueidentifier' ) RETURN 1
   IF (@DataTypeName = 'table'            ) RETURN 0
   IF (@DataTypeName = 'xml'              ) RETURN 0

   -- User defined types not accepted
   RETURN 0

END
GO


-- =======================================================================
-- FUNCTION : SFN_Internal_GetColumnPart
-- Generates a portion of the SQL query that is used in RunTableComparison. 
-- See RunTableComparison and GenerateComparisonSQLQuery.
-- =======================================================================
CREATE FUNCTION Internal.SFN_Internal_GetColumnPart(
   @BareColumnName   sysname, 
   @DataTypeName     nvarchar(128), 
   @MaxLength        int, 
   @ColumnPrecision int) RETURNS nvarchar(max)
AS
BEGIN

   DECLARE @ExpectedResultConvertString   nvarchar(max)
   DECLARE @ActualResultConvertString     nvarchar(max)
   DECLARE @ColumnPartString              nvarchar(max)
   DECLARE @ReplacementValue              nvarchar(max)
   DECLARE @EscapedColumnName             sysname

   DECLARE @ConvertType     varchar(20)
   DECLARE @ConvertLength   varchar(20)
   DECLARE @ConvertStyle    varchar(20)
   DECLARE @UseConvert      int           -- 1 Use CONVERT
                                          -- 2 Use the column without aplying CONVERT
                                          -- 3 Use the string contained in @ReplacementValue

   SET @ConvertType     = 'varchar'
   SET @ConvertLength   = ''           -- We assume we don't need to specify the lenght in CONVERT
   SET @ConvertStyle    = ''           -- We asume that we don't need to specify the style in CONVERT
   SET @UseConvert      = 1            -- We assume that we do need to use CONVERT to nvarchar
   SET @EscapedColumnName = '[' + @BareColumnName + ']'

   IF      (@DataTypeName = 'money'            )    BEGIN SET @ConvertStyle = ', 2'; END
   ELSE IF (@DataTypeName = 'smallmoney'       )    BEGIN SET @ConvertStyle = ', 2'; END
   ELSE IF (@DataTypeName = 'decimal'          )    BEGIN SET @ConvertLength = '(' + CAST(@ColumnPrecision + 10 AS varchar) + ')'; END
   ELSE IF (@DataTypeName = 'numeric'          )    BEGIN SET @ConvertLength = '(' + CAST(@ColumnPrecision + 10 AS varchar) + ')'; END
   ELSE IF (@DataTypeName = 'float'            )    BEGIN SET @ConvertStyle = ', 2'; SET @ConvertLength = '(30)'; END
   ELSE IF (@DataTypeName = 'real'             )    BEGIN SET @ConvertStyle = ', 1'; SET @ConvertLength = '(30)'; END
   ELSE IF (@DataTypeName = 'datetime'         )    BEGIN SET @ConvertStyle = ', 121'; END
   ELSE IF (@DataTypeName = 'smalldatetime'    )    BEGIN SET @ConvertStyle = ', 120'; END
   ELSE IF (@DataTypeName = 'char'             )    BEGIN SET @ConvertLength = '(' + CAST(@MaxLength AS varchar) + ')'; END
   ELSE IF (@DataTypeName = 'nchar'            )    BEGIN SET @ConvertLength = '(' + CAST(@MaxLength/2 AS varchar) + ')'; SET @ConvertType = 'nvarchar'; END
   ELSE IF (@DataTypeName = 'varchar'          )    
   BEGIN 
      IF (@MaxLength = -1) SET @ConvertLength = '(max)'
      ELSE                 SET @ConvertLength = '(' + CAST(@MaxLength AS varchar) + ')'
   END
   ELSE IF (@DataTypeName = 'nvarchar'         )    
   BEGIN 
      SET @ConvertType = 'nvarchar'
      IF (@MaxLength = -1) SET @ConvertLength = '(max)'
      ELSE                 SET @ConvertLength = '(' + CAST(@MaxLength/2 AS varchar) + ')'
   END
   ELSE IF (@DataTypeName = 'binary'           )    BEGIN SET @ReplacementValue = '...binary value...'; SET @UseConvert = 3; END
   ELSE IF (@DataTypeName = 'varbinary'        )    BEGIN SET @ReplacementValue = '...binary value...'; SET @UseConvert = 3; END
   ELSE IF (@DataTypeName = 'uniqueidentifier' )    BEGIN SET @ConvertLength = '(36)'; END



   IF (@UseConvert = 1)
   BEGIN
      SET @ExpectedResultConvertString = 'CONVERT(' + @ConvertType + @ConvertLength + ', #ExpectedResult.' + @EscapedColumnName + @ConvertStyle + ') COLLATE database_default '
      SET @ActualResultConvertString   = 'CONVERT(' + @ConvertType + @ConvertLength + ', #ActualResult.'   + @EscapedColumnName + @ConvertStyle + ') COLLATE database_default '
   END
   ELSE IF (@UseConvert = 2)
   BEGIN
      SET @ExpectedResultConvertString = '#ExpectedResult.' + @EscapedColumnName
      SET @ActualResultConvertString   = '#ActualResult.' + @EscapedColumnName
   END

   IF (@UseConvert = 3)
   BEGIN
      SET @ColumnPartString = '''' + @BareColumnName + '=(' + @ReplacementValue + '/' + @ReplacementValue + ') '' '
   END
   ELSE
   BEGIN
      SET @ColumnPartString = '''' + @BareColumnName + 
               '=('' + ISNULL('     + @ExpectedResultConvertString + ', ''null'')' + 
               ' + ''/'' + ISNULL(' + @ActualResultConvertString   + ', ''null'') + '') '' '
   END
   
   RETURN @ColumnPartString

END
GO

-- =======================================================================
-- PROCEDURE: GenerateComparisonSQLQuery
-- Generates a SQL query that is used in RunTableComparison. 
-- See RunTableComparison.
-- Asumes that #SchemaInfoExpectedResults and #SchemaInfoActualResults
-- are already created and contain the appropiate data.
-- =======================================================================
CREATE PROCEDURE Internal.GenerateComparisonSQLQuery
   @SqlCommand nvarchar(max)OUT
AS
BEGIN

   DECLARE @IsTheFirstColumn           bit
   DECLARE @DataTypeName               nvarchar(128)
   DECLARE @ColumnPrecision            int
   DECLARE @MaxLength                  int
   DECLARE @SqlCommandPkColumns        nvarchar(max)
   DECLARE @SqlCommandDataColumns      nvarchar(max)
   DECLARE @SqlCommandInnerJoinClause  nvarchar(max)
   DECLARE @SqlCommandWhereClause      nvarchar(max)
   DECLARE @Params                     nvarchar(100)
   DECLARE @BareColumnName             sysname
   DECLARE @EscapedColumnName          sysname

   DECLARE CrsPkColumns CURSOR FOR
      SELECT ColumnName, DataTypeName, MaxLength, ColumnPrecision      
      FROM #SchemaInfoActualResults
      WHERE IsPrimaryKey = 1
      ORDER BY PkOrdinal

   OPEN CrsPkColumns

   SET @IsTheFirstColumn = 1
   SET @SqlCommandPkColumns = ''
   SET @SqlCommandWhereClause = ''
   SET @SqlCommandInnerJoinClause = ''
   FETCH NEXT FROM CrsPkColumns INTO @BareColumnName, @DataTypeName, @MaxLength, @ColumnPrecision
   WHILE @@FETCH_STATUS = 0
   BEGIN
   
      SET @EscapedColumnName = '[' + @BareColumnName + ']'
      IF (@IsTheFirstColumn = 0) SET @SqlCommandPkColumns = @SqlCommandPkColumns + ' + '
      SET @SqlCommandPkColumns = @SqlCommandPkColumns + Internal.SFN_Internal_GetColumnPart(@BareColumnName, @DataTypeName, @MaxLength, @ColumnPrecision)

      IF (@IsTheFirstColumn = 0) SET @SqlCommandInnerJoinClause = @SqlCommandInnerJoinClause + ' AND ' 
      SET @SqlCommandInnerJoinClause = @SqlCommandInnerJoinClause + '#ActualResult.' + @EscapedColumnName + ' = #ExpectedResult.' + @EscapedColumnName 

      IF (@IsTheFirstColumn = 0) SET @SqlCommandWhereClause = @SqlCommandWhereClause + ' OR ' 
      SET @SqlCommandWhereClause = @SqlCommandWhereClause + 
         '(  ( (#ActualResult.' + @EscapedColumnName + ' IS NOT NULL) AND (#ExpectedResult.' + @EscapedColumnName + ' IS NULL    ) )  OR ' +
         '   ( (#ActualResult.' + @EscapedColumnName + ' IS NULL    ) AND (#ExpectedResult.' + @EscapedColumnName + ' IS NOT NULL) )  OR ' + 
         '   (#ActualResult.' + @EscapedColumnName + ' != #ExpectedResult.' + @EscapedColumnName + ') )' 

      SET @IsTheFirstColumn = 0
      
      FETCH NEXT FROM CrsPkColumns INTO @BareColumnName, @DataTypeName, @MaxLength, @ColumnPrecision
   END
   
   CLOSE CrsPkColumns
   DEALLOCATE CrsPkColumns

   DECLARE CrsDataColumns CURSOR FOR
      SELECT ColumnName, DataTypeName, MaxLength, ColumnPrecision      
      FROM #SchemaInfoActualResults
      WHERE 
         IsPrimaryKey = 0
         AND IsIgnored = 0

   OPEN CrsDataColumns

   SET @IsTheFirstColumn = 1
   SET @SqlCommandDataColumns = ''
   FETCH NEXT FROM CrsDataColumns INTO @BareColumnName, @DataTypeName, @MaxLength, @ColumnPrecision      
   WHILE @@FETCH_STATUS = 0
   BEGIN

      SET @EscapedColumnName = '[' + @BareColumnName + ']'
      SET @SqlCommandDataColumns = @SqlCommandDataColumns + ' + ' + Internal.SFN_Internal_GetColumnPart(@BareColumnName, @DataTypeName, @MaxLength, @ColumnPrecision)

      SET @SqlCommandWhereClause = @SqlCommandWhereClause + ' OR ' 
      SET @SqlCommandWhereClause = @SqlCommandWhereClause + 
         '(  ( (#ActualResult.' + @EscapedColumnName + ' IS NOT NULL) AND (#ExpectedResult.' + @EscapedColumnName + ' IS NULL    ) )  OR ' +
         '   ( (#ActualResult.' + @EscapedColumnName + ' IS NULL    ) AND (#ExpectedResult.' + @EscapedColumnName + ' IS NOT NULL) )  OR ' + 
         '   (#ActualResult.' + @EscapedColumnName + ' != #ExpectedResult.' + @EscapedColumnName + ') )' 

      SET @IsTheFirstColumn = 0
      
      FETCH NEXT FROM CrsDataColumns INTO @BareColumnName, @DataTypeName, @MaxLength, @ColumnPrecision      
   END
   
   CLOSE CrsDataColumns
   DEALLOCATE CrsDataColumns

   SET @SqlCommand = ' SELECT TOP 1 @DifString = '  + 
                     @SqlCommandPkColumns +
                     @SqlCommandDataColumns +
                     ' FROM #ExpectedResult FULL OUTER JOIN #ActualResult ON ' + 
                     @SqlCommandInnerJoinClause +
                     ' WHERE ' + 
                     @SqlCommandWhereClause

END
GO

-- =======================================================================
-- PROCEDURE: RunTableComparison
-- Generates a SQL query that will pick up one row where the data in
-- #ExpectedResult and #ActualResult is not the same. Runs the query 
-- and by this determines if the data in #ExpectedResult and #ActualResult 
-- is the same or not. 
-- Asumes that #SchemaInfoExpectedResults and #SchemaInfoActualResults
-- are already created and contain the appropiate data.
-- Return code:
--    0 - The comparison was performed. 
--          - If the validation passed (the data in #ExpectedResult and 
--            #ActualResult is the same) then @DifferenceRowInfo will be NULL
--          - If the validation did not passed then @DifferenceRowInfo will 
--            contain a string showing data in one row that is different between
--            #ExpectedResult and #ActualResult 
--    1 - The comparison failed with an internal error. The appropiate 
--        error was logged
-- =======================================================================
CREATE PROCEDURE Internal.RunTableComparison
   @DifferenceRowInfo nvarchar(max) OUT
AS
BEGIN

   DECLARE @SqlCommand                 nvarchar(max)
   DECLARE @Params                     nvarchar(100)

   EXEC Internal.GenerateComparisonSQLQuery @SqlCommand OUT

   -- PRINT ISNULL(@SqlCommand, 'null')

   IF (@SqlCommand IS NULL)
   BEGIN
      EXEC Internal.LogErrorMessageAndRaiseError 'TST Internal Error in RunTableComparison. @SqlCommand is NULL'
      RETURN 1
   END
                  
   SET @Params = '@DifString nvarchar(max) OUT'
   BEGIN TRY
      EXEC sp_executesql @SqlCommand, @Params, @DifString=@DifferenceRowInfo OUT
   END TRY
   BEGIN CATCH
      DECLARE @ErrorMessage    nvarchar(4000)

      -- Build the message string that will contain the original error information.
      PRINT 'TST Internal Error in RunTableComparison.'
      SELECT @ErrorMessage = 'TST Internal Error in RunTableComparison. ' + 
         'Error '       + ISNULL(CAST(ERROR_NUMBER()     as varchar        ), 'N/A') + 
         ', Level '     + ISNULL(CAST(ERROR_SEVERITY()   as varchar        ), 'N/A') + 
         ', State '     + ISNULL(CAST(ERROR_STATE()      as varchar        ), 'N/A') + 
         ', Procedure ' + ISNULL(CAST(ERROR_PROCEDURE()  as nvarchar(128)   ), 'N/A') + 
         ', Line '      + ISNULL(CAST(ERROR_LINE()       as varchar        ), 'N/A') + 
         ', Message: '  + ISNULL(CAST(ERROR_MESSAGE()    as nvarchar(2048)  ), 'N/A')

      EXEC Internal.LogErrorMessageAndRaiseError @ErrorMessage
      RETURN 1
   
   END CATCH

   RETURN 0
   
END
GO


-- =======================================================================
-- FUNCTION: GetSqlVarInfo
-- Determines the data type and the data type family for the value 
-- stored in @SqlVariant.
-- Also converts @SqlVariant in a string applying a CONVERT that will 
-- force the maximum precision.
--    The data type           The data type family             Abreviation
--       sql_variant                sql_variant                SV
--       datetime                   Date and Time              DT
--       smalldatetime              Date and Time              DT
--       float                      Approximate numeric        AN
--       real                       Approximate numeric        AN
--       numeric                    Exact numeric              EN
--       decimal                    Exact numeric              EN
--       money                      Exact numeric              EN
--       smallmoney                 Exact numeric              EN
--       bigint                     Exact numeric              EN
--       int                        Exact numeric              EN
--       smallint                   Exact numeric              EN
--       tinyint                    Exact numeric              EN
--       bit                        Exact numeric              EN
--       nvarchar                   Unicode                    UC
--       nchar                      Unicode                    UC
--       varchar                    Unicode                    UC
--       char                       Unicode                    UC
--       varbinary                  Binary                     BI
--       binary                     Binary                     BI
--       uniqueidentifier           Uniqueidentifier           UQ
--       Other                      Other                      ??
--
-- If @SqlVariant is NULL then both @BaseType and @DataTypeFamily will 
-- be returend as NULL.
-- =======================================================================
CREATE PROCEDURE Internal.GetSqlVarInfo
   @SqlVariant       sql_variant,
   @BaseType         sysname OUT,
   @DataTypeFamily   char(2) OUT,
   @StringValue      nvarchar(max) OUT
AS
BEGIN

   SET @BaseType         = NULL
   SET @DataTypeFamily   = NULL
   SET @StringValue      = 'NULL'
   
   IF (@SqlVariant IS NULL) RETURN

   SET @BaseType = CAST(SQL_VARIANT_PROPERTY (@SqlVariant, 'BaseType') AS sysname)
   SET @StringValue = CONVERT(nvarchar(max), @SqlVariant); 
         IF (@BaseType = 'sql_variant'      ) BEGIN SET @DataTypeFamily = 'SV'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant      ); END
   ELSE  IF (@BaseType = 'datetime'         ) BEGIN SET @DataTypeFamily = 'DT'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant, 121 ); END
   ELSE  IF (@BaseType = 'smalldatetime'    ) BEGIN SET @DataTypeFamily = 'DT'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant, 121 ); END
   ELSE  IF (@BaseType = 'float'            ) BEGIN SET @DataTypeFamily = 'AN'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant, 2   ); END
   ELSE  IF (@BaseType = 'real'             ) BEGIN SET @DataTypeFamily = 'AN'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant, 2   ); END
   ELSE  IF (@BaseType = 'numeric'          ) BEGIN SET @DataTypeFamily = 'EN'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant      ); END
   ELSE  IF (@BaseType = 'decimal'          ) BEGIN SET @DataTypeFamily = 'EN'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant      ); END
   ELSE  IF (@BaseType = 'money'            ) BEGIN SET @DataTypeFamily = 'EN'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant, 2   ); END
   ELSE  IF (@BaseType = 'smallmoney'       ) BEGIN SET @DataTypeFamily = 'EN'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant, 2   ); END
   ELSE  IF (@BaseType = 'bigint'           ) BEGIN SET @DataTypeFamily = 'EN'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant      ); END
   ELSE  IF (@BaseType = 'int'              ) BEGIN SET @DataTypeFamily = 'EN'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant      ); END
   ELSE  IF (@BaseType = 'smallint'         ) BEGIN SET @DataTypeFamily = 'EN'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant      ); END
   ELSE  IF (@BaseType = 'tinyint'          ) BEGIN SET @DataTypeFamily = 'EN'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant      ); END
   ELSE  IF (@BaseType = 'bit'              ) BEGIN SET @DataTypeFamily = 'EN'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant      ); END
   ELSE  IF (@BaseType = 'nvarchar'         ) BEGIN SET @DataTypeFamily = 'UC'; SET @StringValue = '''' + CONVERT(nvarchar(max), @SqlVariant) + ''''; END
   ELSE  IF (@BaseType = 'nchar'            ) BEGIN SET @DataTypeFamily = 'UC'; SET @StringValue = '''' + CONVERT(nvarchar(max), @SqlVariant) + ''''; END
   ELSE  IF (@BaseType = 'varchar'          ) BEGIN SET @DataTypeFamily = 'UC'; SET @StringValue = '''' + CONVERT(nvarchar(max), @SqlVariant) + ''''; END
   ELSE  IF (@BaseType = 'char'             ) BEGIN SET @DataTypeFamily = 'UC'; SET @StringValue = '''' + CONVERT(nvarchar(max), @SqlVariant) + ''''; END
   ELSE  IF (@BaseType = 'varbinary'        ) BEGIN SET @DataTypeFamily = 'BI'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant      ); END
   ELSE  IF (@BaseType = 'binary'           ) BEGIN SET @DataTypeFamily = 'BI'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant      ); END
   ELSE  IF (@BaseType = 'uniqueidentifier' ) BEGIN SET @DataTypeFamily = 'UQ'; SET @StringValue = '{' + CONVERT(nvarchar(max), @SqlVariant) + '}'; END
   ELSE                                       BEGIN SET @DataTypeFamily = '??'; SET @StringValue = CONVERT(nvarchar(max), @SqlVariant      ); END

END
GO


-- =======================================================================
-- FUNCTION SFN_GetTestProcedurePrefix
-- Returns the prefix used to identify test procedures 
-- for the given test database.
-- This prefix can be customized in table Data.TSTVariables.
-- By default this is "SQLTest_".
-- =======================================================================
CREATE FUNCTION Internal.SFN_GetTestProcedurePrefix(@TestDatabaseName sysname) RETURNS varchar(32)
AS
BEGIN

   DECLARE @TestProcedurePrefix     varchar(100)

   -- Set @TestProcedurePrefix to its default value in case none is specified in the table Data.TSTVariables.
   SET @TestProcedurePrefix = 'SQLTest_'

   -- Overwrite @TestProcedurePrefix with the value specified in Data.TSTVariables for the global scope.
   SELECT @TestProcedurePrefix = VariableValue
   FROM Data.TSTVariables
   WHERE 
      DatabaseName IS NULL 
      AND VariableName  = 'SqlTestPrefix' 

   -- Overwrite @TestProcedurePrefix with the value specified in Data.TSTVariables for the given test database.
   SELECT @TestProcedurePrefix = VariableValue
   FROM Data.TSTVariables
   WHERE 
      DatabaseName = @TestDatabaseName
      AND VariableName  = 'SqlTestPrefix' 

   RETURN @TestProcedurePrefix
   
END
GO


-- =======================================================================
-- PROCEDURE SetTSTVariable
-- Sets a TST variable.
-- =======================================================================
CREATE PROCEDURE Utils.SetTSTVariable
   @TestDatabaseName    sysname, 
   @TSTVariableName     varchar(32),
   @TSTVariableValue    varchar(100)
AS
BEGIN

   IF EXISTS (SELECT * FROM Data.TSTVariables WHERE (DatabaseName=@TestDatabaseName OR (DatabaseName IS NULL AND @TestDatabaseName IS NULL)) AND VariableName=@TSTVariableName)
   BEGIN
      UPDATE Data.TSTVariables SET VariableValue=@TSTVariableValue
      WHERE (DatabaseName=@TestDatabaseName OR (DatabaseName IS NULL AND @TestDatabaseName IS NULL)) AND VariableName=@TSTVariableName
   END
   ELSE
   BEGIN
      INSERT INTO Data.TSTVariables(DatabaseName, VariableName, VariableValue) VALUES (@TestDatabaseName, @TSTVariableName, @TSTVariableValue)
   END

END
GO

-- =======================================================================
-- END TST Internals.
-- =======================================================================

-- =======================================================================
-- START TST API.
-- These are stored procedures that are typicaly called from within the 
-- test stored procedures.
-- =======================================================================

-- =======================================================================
-- PROCEDURE: SetConfiguration
-- Sets up TST parameters. Typically called by the tests in the SETUP 
-- procedure or in the TSTConfig procedures. 
-- In case of an invalid call it will raise an error and return 1
-- =======================================================================
CREATE PROCEDURE Utils.SetConfiguration
   @ParameterName       varchar(32),        -- See table TSTParameters and CK_TSTParameters_ParameterName.
   @ParameterValue      varchar(100),       -- The parameter value. Depends on the ParameterName.
                                            -- See table TSTParameters and CK_TSTParameters_ParameterName.
   @Scope               sysname,            -- See table TSTParameters and CK_TSTParameters_Scope.
   @ScopeValue          sysname = NULL      -- Depends on Scope. 
                                            -- See table TSTParameters and CK_TSTParameters_Scope.
AS
BEGIN

   DECLARE @TestSessionId           int
   DECLARE @TestDatabaseName        sysname
   DECLARE @SuiteExists             bit
   DECLARE @TestProcedurePrefix     varchar(100)

   SELECT @TestSessionId = TestSessionId FROM #Tmp_CrtSessionInfo
   SELECT @TestDatabaseName = TestSession.DatabaseName FROM Data.TestSession WHERE TestSessionId = @TestSessionId

   SELECT @TestProcedurePrefix = Internal.SFN_GetTestProcedurePrefix(@TestDatabaseName)

   IF (@ParameterName != 'UseTSTRollback')
   BEGIN
         RAISERROR('Invalid call to SetConfiguration. @ParameterName has an invalid value: ''%s''.', 16, 1, @ParameterName)
         RETURN 1
   END
   
   -- Validate parameters
   IF (@ParameterName='UseTSTRollback')
   BEGIN
      IF (@ParameterValue IS NULL OR (@ParameterValue != '0' AND @ParameterValue != '1') )
      BEGIN
         RAISERROR('Invalid call to SetConfiguration. @ParameterValue has an invalid value: ''%s''. Valid values are ''0'' and ''1''', 16, 1, @ParameterValue)
         RETURN 1
      END
   END
   
   IF (@Scope='All')
   BEGIN
      IF (@ScopeValue IS NOT NULL)
      BEGIN
         RAISERROR('Invalid call to SetConfiguration. @ScopeValue has an invalid value: ''%s''. When @Scope=''All'' @ScopeValue can only be NULL', 16, 1, @ScopeValue)
         RETURN 1
      END
   END
   ELSE IF (@Scope='Suite')
   BEGIN
      IF (@ScopeValue IS NULL)
      BEGIN
         RAISERROR('Invalid call to SetConfiguration. @ScopeValue cannot be NULL when @Scope=''Suite''', 16, 1)
         RETURN 1
      END
      
      EXEC Internal.SuiteExists @TestDatabaseName, @ScopeValue, @TestProcedurePrefix, @SuiteExists OUT
      IF (@SuiteExists = 0)
      BEGIN
         RAISERROR('Invalid call to SetConfiguration. Cannot find the suite indicated by @ScopeValue: ''%s''', 16, 1, @ScopeValue)
         RETURN 1
      END
   END
   ELSE IF (@Scope='Test')
   BEGIN
      IF (@ScopeValue IS NULL)
      BEGIN
         RAISERROR('Invalid call to SetConfiguration. @ScopeValue cannot be NULL when @Scope=''Test''', 16, 1)
         RETURN 1
      END

      IF (Internal.SFN_SProcExists(@TestDatabaseName, @ScopeValue) = 0)
      BEGIN
         RAISERROR('Invalid call to SetConfiguration. Cannot find the test indicated by @ScopeValue: ''%s''', 16, 1, @ScopeValue)
         RETURN 1
      END

      -- Make sure that the procedure given by @ScopeValue followsthe namingconvention for a TST test
      DECLARE @SuiteName         sysname
      DECLARE @IsTSTSproc        bit
      DECLARE @SProcType         varchar(10)

      EXEC Internal.AnalyzeSprocName @ScopeValue, @TestProcedurePrefix, @SuiteName OUTPUT, @IsTSTSproc OUTPUT, @SProcType OUTPUT
      IF (@IsTSTSproc = 0 OR @SProcType != 'Test')
      BEGIN
         RAISERROR('Invalid call to SetConfiguration. The test indicated by @ScopeValue: ''%s'' does not follow the naming conventions for a TST test procedure', 16, 1, @ScopeValue)
         RETURN 1
      END
      
   END
   ELSE
   BEGIN
      RAISERROR('Invalid call to SetConfiguration. Invalid value for @Scope: ''%s''', 16, 1, @Scope)
      RETURN 1
   END

   -- Now that the parameters were validated, insert a row in TSTParameters
   INSERT INTO Data.TSTParameters(TestSessionId, ParameterName, ParameterValue, Scope, ScopeValue) 
   VALUES (@TestSessionId, @ParameterName, @ParameterValue, @Scope, @ScopeValue)

END
GO

/*
-- =======================================================================
-- PROCEDURE: DropTestTables
-- If exists then drops the table: #ActualResult
-- If exists then drops the table: #ExpectedResult
-- TODO: Do we need to provide this? 
-- =======================================================================
CREATE PROCEDURE Utils.DropTestTables
AS
BEGIN

   RETURN 
   
   IF (object_id('tempdb..#ExpectedResult') IS NOT NULL) DROP TABLE #ExpectedResult
   IF (object_id('tempdb..#ActualResult') IS NOT NULL) DROP TABLE #ActualResult

END
GO
*/

-- =======================================================================
-- PROCEDURE: DeleteTestTables
-- Deletes all entries from the table: #ActualResult
-- Deletes all entries from the table: #ExpectedResult
-- =======================================================================
CREATE PROCEDURE Utils.DeleteTestTables
AS
BEGIN

   DELETE FROM #ActualResult
   DELETE FROM #ExpectedResult

END
GO

-- =======================================================================
-- PROCEDURE: Log
-- Can be called by the TST test procedures to record an 
-- informational log entry.
-- It will record an entry in TestLog.
-- =======================================================================
CREATE PROCEDURE Assert.LogInfo
   @Message  nvarchar(max)
AS
BEGIN
   DECLARE @TestSessionId int
   DECLARE @TestId int
   
   SELECT @TestSessionId = TestSessionId, @TestId = TestId FROM #Tmp_CrtSessionInfo
   INSERT INTO Data.TestLog(TestSessionId, TestId, EntryType, LogMessage) VALUES(@TestSessionId, @TestId, 'L', ISNULL(@Message, ''))
END
GO

-- =======================================================================
-- PROCEDURE: Ignore
-- Can be called by the test procedures
-- to force a suite or test to be ignored.
-- It will record an entry in TestLog.
-- =======================================================================
CREATE PROCEDURE Assert.Ignore
   @Message nvarchar(max) = ''
AS
BEGIN

   DECLARE @Stage          char
   DECLARE @ErrorMessage   nvarchar(1000)
   DECLARE @TestSessionId  int
   DECLARE @TestId         int

   SELECT @Stage = Stage FROM #Tmp_CrtSessionInfo
   
   IF(@Stage = 'A' OR @Stage = 'X' OR @Stage = 'Z')
   BEGIN
      IF (@Stage = 'A')
      BEGIN
         SET @ErrorMessage = 'The test session setup procedure cannot invoke Assert.Ignore. The Assert.Ignore can only be invoked by a suite setup or by a test procedure.'
      END
      ELSE IF  (@Stage = 'X')
      BEGIN
         SET @ErrorMessage = 'A teardown procedure cannot invoke Assert.Ignore. The Assert.Ignore can only be invoked by a suite setup or by a test procedure.'
      END
      ELSE IF  (@Stage = 'Z')
      BEGIN
         SET @ErrorMessage = 'The test session teardown procedure cannot invoke Assert.Ignore. The Assert.Ignore can only be invoked by a suite setup or by a test procedure.'
      END
      ELSE 
      BEGIN
         SET @ErrorMessage = 'TST Internal Error. Assert.Ignore appears to be called outside of any test context.'
      END

      EXEC Internal.LogErrorMessageAndRaiseError @ErrorMessage
      
   END

   SELECT @TestSessionId = TestSessionId, @TestId = TestId FROM #Tmp_CrtSessionInfo
   INSERT INTO Data.TestLog(TestSessionId, TestId, EntryType, LogMessage) VALUES(@TestSessionId, @TestId, 'I', ISNULL(@Message, '') )
   RAISERROR('TST RAISERROR {6C57D85A-CE44-49ba-9286-A5227961DF02}', 16, 110)

END
GO

-- =======================================================================
-- PROCEDURE: Pass
-- Can be called by the test procedures to mark a test pass. 
-- It will record an entry in TestLog.
-- =======================================================================
ALTER PROCEDURE Assert.Pass
   @Message nvarchar(max) = ''
AS
BEGIN
   DECLARE @TestSessionId int
   DECLARE @TestId int
   
   SELECT @TestSessionId = TestSessionId, @TestId = TestId FROM #Tmp_CrtSessionInfo
   INSERT INTO Data.TestLog(TestSessionId, TestId, EntryType, LogMessage) VALUES(@TestSessionId, @TestId, 'P', ISNULL(@Message, '') )
END
GO

-- =======================================================================
-- PROCEDURE: Fail
-- Can be called by the test procedures to mark a test failure. 
-- It will record an entry in TestLog and raise an exception.
-- =======================================================================
ALTER PROCEDURE Assert.Fail
   @ErrorMessage  nvarchar(max)
AS
BEGIN
   DECLARE @TestSessionId int
   DECLARE @TestId int
   
   SELECT @TestSessionId = TestSessionId, @TestId = TestId FROM #Tmp_CrtSessionInfo
   INSERT INTO Data.TestLog(TestSessionId, TestId, EntryType, LogMessage) VALUES(@TestSessionId, @TestId, 'F', ISNULL(@ErrorMessage, ''))
   RAISERROR('TST RAISERROR {6C57D85A-CE44-49ba-9286-A5227961DF02}', 16, 110)
END
GO

-- =======================================================================
-- PROCEDURE: ClearExpectedError
-- Clear the info about the expected error.
-- =======================================================================
ALTER PROCEDURE Internal.ClearExpectedError
AS
BEGIN
   UPDATE #Tmp_CrtSessionInfo SET 
      ExpectedErrorNumber          = NULL,
      ExpectedErrorMessage         = NULL, 
      ExpectedErrorProcedure       = NULL,
      ExpectedErrorContextMessage  = NULL
END
GO

-- =======================================================================
-- PROCEDURE: RegisterExpectedError
-- Can be called by the test procedures to register an expected error.
-- TODO: Error out if all error params are null
-- TODO: Add severity and level
-- =======================================================================
CREATE PROCEDURE Assert.RegisterExpectedError
   @ContextMessage            nvarchar(1000),
   @ExpectedErrorMessage      nvarchar(2048) = NULL,
   @ExpectedErrorProcedure    nvarchar(126) = NULL,
   @ExpectedErrorNumber       int = NULL
AS
BEGIN

   DECLARE @Stage          char
   DECLARE @ErrorMessage   nvarchar(1000)

   SELECT @Stage = Stage FROM #Tmp_CrtSessionInfo
   
   IF(@Stage != 'T')
   BEGIN
      IF (@Stage = 'A')
      BEGIN
         SET @ErrorMessage = 'The test session setup procedure cannot invoke RegisterExpectedError. RegisterExpectedError can only be invoked by a test procedure before the error is raised.'
      END
      ELSE IF (@Stage = 'S')
      BEGIN
         SET @ErrorMessage = 'A setup procedure cannot invoke RegisterExpectedError. RegisterExpectedError can only be invoked by a test procedure before the error is raised.'
      END
      ELSE IF  (@Stage = 'X')
      BEGIN
         SET @ErrorMessage = 'A teardown procedure cannot invoke RegisterExpectedError. RegisterExpectedError can only be invoked by a test procedure before the error is raised.'
      END
      ELSE IF  (@Stage = 'Z')
      BEGIN
         SET @ErrorMessage = 'The test session teardown procedure cannot invoke RegisterExpectedError. RegisterExpectedError can only be invoked by a test procedure before the error is raised.'
      END
      ELSE 
      BEGIN
         SET @ErrorMessage = 'TST Internal Error. RegisterExpectedError appears to be called outside of any test context.'
      END

      EXEC Internal.LogErrorMessageAndRaiseError @ErrorMessage
      
   END

   UPDATE #Tmp_CrtSessionInfo SET 
      ExpectedErrorNumber          = @ExpectedErrorNumber          ,
      ExpectedErrorMessage         = @ExpectedErrorMessage         ,
      ExpectedErrorProcedure       = @ExpectedErrorProcedure       ,
      ExpectedErrorContextMessage  = @ContextMessage  

END
GO

-- =======================================================================
-- PROCEDURE: Assert.Equals
-- Can be called by the test procedures to verify that 
-- two values are equal. 
-- Note: NULL is invalid for @ExpectedValue. If Assert.Equals is
--       called with NULL for @ExpectedValue then it will fail with 
--       an ERROR. Use Assert.IsNull instead.
-- Result map:
--       @ExpectedValue    @ActualValue      Result
--                 NULL         Ignored        ERROR
--                value            NULL        Fail
--               value1          value2        Fail
--               value1          value1        Pass
-- If passes it will record an entry in TestLog.
-- If failes it will record an entry in TestLog and raise an error.
-- =======================================================================
CREATE PROCEDURE Assert.Equals
   @ContextMessage      nvarchar(1000),
   @ExpectedValue       sql_variant,
   @ActualValue         sql_variant
AS
BEGIN

   DECLARE @ExpectedValueDataType         sysname
   DECLARE @ExpectedValueDataTypeFamily   char(2)
   DECLARE @ActualValueDataType           sysname
   DECLARE @ActualValueDataTypeFamily     char(2)
   DECLARE @ExpectedValueString           nvarchar(max)
   DECLARE @ActualValueString             nvarchar(max)
   DECLARE @Message                       nvarchar(4000)

   SET @ContextMessage = ISNULL(@ContextMessage, '')

   IF (@ExpectedValue IS NULL )
   BEGIN
      SET @Message = 'Invalid call to Assert.Equals. [' + @ContextMessage + '] @ExpectedValue cannot be NULL. Use Assert.IsNull instead.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@ActualValue IS NULL )
   BEGIN
      SET @Message = 'Assert.Equals failed. [' + @ContextMessage + '] Actual value is NULL'
      EXEC Assert.Fail @Message
   END

   EXEC Internal.GetSqlVarInfo @ExpectedValue , @ExpectedValueDataType OUT, @ExpectedValueDataTypeFamily OUT, @ExpectedValueString OUT
   EXEC Internal.GetSqlVarInfo @ActualValue   , @ActualValueDataType   OUT, @ActualValueDataTypeFamily   OUT, @ActualValueString   OUT

   IF(@ExpectedValueDataTypeFamily != @ActualValueDataTypeFamily OR 
      @ExpectedValueDataTypeFamily = 'SV' OR 
      @ExpectedValueDataTypeFamily = '??')
   BEGIN
      SET @Message = 'Invalid call to Assert.Equals. [' + @ContextMessage + '] @ExpectedValue (' + @ExpectedValueDataType + ') and @ActualValue (' + @ActualValueDataType + ') have incompatible types. Consider an explicit CONVERT, calling Assert.NumericEquals or calling Assert.FloatEquals'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@ExpectedValueDataTypeFamily = 'AN')
   BEGIN
      SET @Message = 'Invalid call to Assert.Equals. [' + @ContextMessage + '] Float or real cannot be used when calling Assert.Equals since this could produce unreliable results. Use Assert.FloatEquals.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@ActualValue = @ExpectedValue)
   BEGIN
      SET @Message = 
            'Assert.Equals passed. [' + @ContextMessage + '] Test value: ' + @ExpectedValueString + ' (' + @ExpectedValueDataType + ')' + 
            '. Actual value: ' + @ActualValueString + ' (' + @ActualValueDataType + ')'
      EXEC Assert.Pass @Message
      RETURN
   END

   SET @Message = 
            'Assert.Equals failed. [' + @ContextMessage + '] Test value: ' + @ExpectedValueString + ' (' + @ExpectedValueDataType + ')' + 
            '. Actual value: ' + @ActualValueString + ' (' + @ActualValueDataType + ')'
   EXEC Assert.Fail @Message

END
GO

-- =======================================================================
-- PROCEDURE: Assert.NotEquals
-- Can be called by the test procedures to verify that 
-- two values are not equal. 
-- Note: NULL is invalid for @ExpectedNotValue. If Assert.NotEquals is 
--       called with NULL for @ExpectedNotValue then it will fail with 
--       an ERROR. Use Assert.IsNotNull instead.
-- Result map:
--    @ExpectedNotValue    @ActualValue      Result
--                 NULL         Ignored        ERROR
--                value            NULL        Fail
--               value1          value2        Pass
--               value1          value1        Fail
-- If passes it will record an entry in TestLog.
-- If failes it will record an entry in TestLog and raise an error.
-- =======================================================================
CREATE PROCEDURE Assert.NotEquals
   @ContextMessage      nvarchar(1000),
   @ExpectedNotValue    sql_variant,
   @ActualValue         sql_variant
AS
BEGIN

   DECLARE @ExpectedNotValueDataType         sysname
   DECLARE @ExpectedNotValueDataTypeFamily   char(2)
   DECLARE @ActualValueDataType              sysname
   DECLARE @ActualValueDataTypeFamily        char(2)
   DECLARE @ExpectedNotValueString           nvarchar(max)
   DECLARE @ActualValueString                nvarchar(max)
   DECLARE @Message                          nvarchar(4000)

   SET @ContextMessage = ISNULL(@ContextMessage, '')

   IF (@ExpectedNotValue IS NULL )
   BEGIN
      SET @Message = 'Invalid call to Assert.NotEquals. [' + @ContextMessage + '] @ExpectedNotValue cannot be NULL. Use Assert.IsNotNull instead.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@ActualValue IS NULL )
   BEGIN
      SET @Message = 'Assert.NotEquals failed. [' + @ContextMessage + '] Actual value is NULL'
      EXEC Assert.Fail @Message
   END

   EXEC Internal.GetSqlVarInfo @ExpectedNotValue , @ExpectedNotValueDataType OUT, @ExpectedNotValueDataTypeFamily OUT, @ExpectedNotValueString OUT
   EXEC Internal.GetSqlVarInfo @ActualValue      , @ActualValueDataType      OUT, @ActualValueDataTypeFamily      OUT, @ActualValueString      OUT

   IF(@ExpectedNotValueDataTypeFamily != @ActualValueDataTypeFamily OR 
      @ExpectedNotValueDataTypeFamily = 'SV' OR 
      @ExpectedNotValueDataTypeFamily = '??')
   BEGIN
      SET @Message = 'Invalid call to Assert.NotEquals. [' + @ContextMessage + '] @ExpectedNotValue (' + @ExpectedNotValueDataType + ') and @ActualValue (' + @ActualValueDataType + ') have incompatible types. Consider an explicit CONVERT, calling Assert.NumericEquals or calling Assert.FloatEquals'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@ExpectedNotValueDataTypeFamily = 'AN')
   BEGIN
      SET @Message = 'Invalid call to Assert.NotEquals. [' + @ContextMessage + '] Float or real cannot be used when calling Assert.NotEquals since this could produce unreliable results. Use Assert.FloatNotEquals.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@ActualValue != @ExpectedNotValue)
   BEGIN
      SET @Message = 
         'Assert.NotEquals passed. [' + @ContextMessage + '] Test value: ' + @ExpectedNotValueString + ' (' +  + @ExpectedNotValueDataType + ')' + 
         '. Actual value: ' + @ActualValueString + ' (' + @ActualValueDataType + ')'
      EXEC Assert.Pass @Message
      RETURN
   END

   SET @Message = 
         'Assert.NotEquals failed. [' + @ContextMessage + '] Test value: ' + @ExpectedNotValueString + ' (' +  + @ExpectedNotValueDataType + ')' + 
         '. Actual value: ' + @ActualValueString + ' (' + @ActualValueDataType + ')'
   EXEC Assert.Fail @Message

END
GO

-- =======================================================================
-- PROCEDURE: Assert.NumericEquals
-- Can be called by the test procedures to verify that 
-- two numbers are equal considering a specified tolerance. 
-- Note: NULL is invalid for @ExpectedValue. If Assert.NumericEquals is
--       called with NULL for @ExpectedValue then it will fail with 
--       an ERROR. Use Assert.IsNull instead.
-- Note: NULL is invalid for @Tolerance. If Assert.NumericEquals is
--       called with NULL for @Tolerance then it will fail with 
--       an ERROR.
-- Note: @Tolerance must be greater or equal than 0. If Assert.NumericEquals is
--       called with a negative number for @Tolerance then it will fail 
--       with an ERROR.
-- Note: If @ActualValue is NULL then Assert.NumericEquals will fail.
-- If passes it will record an entry in TestLog.
-- If failes it will record an entry in TestLog and raise an error.
-- =======================================================================
CREATE PROCEDURE Assert.NumericEquals
   @ContextMessage      nvarchar(1000),
   @ExpectedValue       decimal(38, 15),
   @ActualValue         decimal(38, 15),
   @Tolerance           decimal(38, 15)
AS
BEGIN
   DECLARE @Message     nvarchar(4000)
   DeCLARE @Difference  decimal(38, 15)
   
   SET @ContextMessage = ISNULL(@ContextMessage, '')

   IF (@ExpectedValue IS NULL )
   BEGIN
      SET @Message = 'Invalid call to Assert.NumericEquals. [' + @ContextMessage + '] @ExpectedValue cannot be NULL. Use Assert.IsNull instead.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@Tolerance IS NULL )
   BEGIN
      SET @Message = 'Invalid call to Assert.NumericEquals. [' + @ContextMessage + '] @Tolerance cannot be NULL.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@Tolerance <0)
   BEGIN
      SET @Message = 'Invalid call to Assert.NumericEquals. [' + @ContextMessage + '] @Tolerance must be a zero or a positive number.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   SET @Difference = @ActualValue - @ExpectedValue
   IF (@Difference < 0) SET @Difference = -@Difference

   IF (@Difference <= @Tolerance)
   BEGIN
      SET @Message = 
         'Assert.NumericEquals passed. [' + @ContextMessage + '] Test value: ' + ISNULL(CONVERT(varchar(50), @ExpectedValue, 2), 'NULL') + 
         '. Actual value: ' + ISNULL(CONVERT(varchar(50), @ActualValue, 2), 'NULL') + 
         '. Tolerance: ' + + ISNULL(CONVERT(varchar(50), @Tolerance, 2), 'NULL')
      EXEC Assert.Pass @Message
      RETURN
   END

   SET @Message = 'Assert.NumericEquals failed. [' + @ContextMessage + '] Test value: ' + ISNULL(CONVERT(varchar(50), @ExpectedValue, 2), 'NULL') + 
         '. Actual value: ' + ISNULL(CONVERT(varchar(50), @ActualValue, 2), 'NULL') + 
         '. Tolerance: ' + + ISNULL(CONVERT(varchar(50), @Tolerance, 2), 'NULL')
   EXEC Assert.Fail @Message

END
GO

-- =======================================================================
-- PROCEDURE: Assert.NumericNotEquals
-- Can be called by the test procedures to verify that 
-- two numbers are not equal considering a specified tolerance. 
-- Note: NULL is invalid for @ExpectedValue. If Assert.NumericNotEquals is
--       called with NULL for @ExpectedValue then it will fail with 
--       an ERROR. Use Assert.IsNotNull instead.
-- Note: NULL is invalid for @Tolerance. If Assert.NumericNotEquals is
--       called with NULL for @Tolerance then it will fail with 
--       an ERROR.
-- Note: @Tolerance must be greater or equal than 0. If Assert.NumericNotEquals
--       is called with a negative number for @Tolerance then it will fail
--       with an ERROR.
-- Note: If @ActualValue is NULL then Assert.NumericNotEquals will fail.
-- If passes it will record an entry in TestLog.
-- If failes it will record an entry in TestLog and raise an error.
-- =======================================================================
CREATE PROCEDURE Assert.NumericNotEquals
   @ContextMessage      nvarchar(1000),
   @ExpectedNotValue    decimal(38, 15),
   @ActualValue         decimal(38, 15),
   @Tolerance           decimal(38, 15)
AS
BEGIN
   DECLARE @Message     nvarchar(4000)
   DeCLARE @Difference  decimal(38, 15)
   
   SET @ContextMessage = ISNULL(@ContextMessage, '')

   IF (@ExpectedNotValue IS NULL )
   BEGIN
      SET @Message = 'Invalid call to Assert.NumericNotEquals. [' + @ContextMessage + '] @ExpectedNotValue cannot be NULL. Use Assert.IsNotNull instead.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@Tolerance IS NULL )
   BEGIN
      SET @Message = 'Invalid call to Assert.NumericNotEquals. [' + @ContextMessage + '] @Tolerance cannot be NULL.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@Tolerance <0)
   BEGIN
      SET @Message = 'Invalid call to Assert.NumericNotEquals. [' + @ContextMessage + '] @Tolerance must be a zero or a positive number.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   SET @Difference = @ActualValue - @ExpectedNotValue
   IF (@Difference < 0) SET @Difference = -@Difference

   IF (@Difference > @Tolerance)
   BEGIN
      SET @Message = 
         'Assert.NumericNotEquals passed. [' + @ContextMessage + '] Test value: ' + ISNULL(CONVERT(varchar(50), @ExpectedNotValue, 2), 'NULL') + 
         '. Actual value: ' + ISNULL(CONVERT(varchar(50), @ActualValue, 2), 'NULL') + 
         '. Tolerance: ' + + ISNULL(CONVERT(varchar(50), @Tolerance, 2), 'NULL')
      EXEC Assert.Pass @Message
      RETURN
   END

   SET @Message = 'Assert.NumericNotEquals failed. [' + @ContextMessage + '] Test value: ' + ISNULL(CONVERT(varchar(50), @ExpectedNotValue, 2), 'NULL') + 
         '. Actual value: ' + ISNULL(CONVERT(varchar(50), @ActualValue, 2), 'NULL') + 
         '. Tolerance: ' + + ISNULL(CONVERT(varchar(50), @Tolerance, 2), 'NULL')
   EXEC Assert.Fail @Message

END
GO

-- =======================================================================
-- PROCEDURE: Assert.FloatEquals
-- Can be called by the test procedures to verify that 
-- two numbers are equal considering a specified tolerance. 
-- Use Assert.FloatEquals instead of Assert.NumericEquals is the numbers you 
-- need to compare have high exponents.
-- Note: NULL is invalid for @ExpectedValue. If Assert.FloatEquals is
--       called with NULL for @ExpectedValue then it will fail with 
--       an ERROR. Use Assert.IsNull instead.
-- Note: NULL is invalid for @Tolerance. If Assert.FloatEquals is
--       called with NULL for @Tolerance then it will fail with 
--       an ERROR.
-- Note: @Tolerance must be greater or equal than 0. If Assert.FloatEquals 
--       is called with a negative number for @Tolerance then it will fail
--       with an ERROR.
-- Note: If @ActualValue is NULL then Assert.FloatEquals will fail.
-- If passes it will record an entry in TestLog.
-- If failes it will record an entry in TestLog and raise an error.
-- =======================================================================
CREATE PROCEDURE Assert.FloatEquals
   @ContextMessage      nvarchar(1000),
   @ExpectedValue       float(53),
   @ActualValue         float(53),
   @Tolerance           float(53)
AS
BEGIN
   DECLARE @Message     nvarchar(4000)
   DeCLARE @Difference  float(53)
   
   SET @ContextMessage = ISNULL(@ContextMessage, '')

   IF (@ExpectedValue IS NULL )
   BEGIN
      SET @Message = 'Invalid call to Assert.FloatEquals. [' + @ContextMessage + '] @ExpectedValue cannot be NULL. Use Assert.IsNull instead.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@Tolerance IS NULL )
   BEGIN
      SET @Message = 'Invalid call to Assert.FloatEquals. [' + @ContextMessage + '] @Tolerance cannot be NULL.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@Tolerance <0)
   BEGIN
      SET @Message = 'Invalid call to Assert.FloatEquals. [' + @ContextMessage + '] @Tolerance must be a zero or a positive number.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   SET @Difference = @ActualValue - @ExpectedValue
   IF (@Difference < 0) SET @Difference = -@Difference

   IF (@Difference <= @Tolerance)
   BEGIN
      SET @Message = 
         'Assert.FloatEquals passed. [' + @ContextMessage + '] Test value: ' + ISNULL(CONVERT(varchar(50), @ExpectedValue, 2), 'NULL') + 
         '. Actual value: ' + ISNULL(CONVERT(varchar(50), @ActualValue, 2), 'NULL') + 
         '. Tolerance: ' + + ISNULL(CONVERT(varchar(50), @Tolerance, 2), 'NULL')
      EXEC Assert.Pass @Message
      RETURN
   END

   SET @Message = 'Assert.FloatEquals failed. [' + @ContextMessage + '] Test value: ' + ISNULL(CONVERT(varchar(50), @ExpectedValue, 2), 'NULL') + 
         '. Actual value: ' + ISNULL(CONVERT(varchar(50), @ActualValue, 2), 'NULL') + 
         '. Tolerance: ' + + ISNULL(CONVERT(varchar(50), @Tolerance, 2), 'NULL')
   EXEC Assert.Fail @Message

END
GO

-- =======================================================================
-- PROCEDURE: Assert.FloatNotEquals
-- Can be called by the test procedures to verify that 
-- two numbers are not equal considering a specified tolerance. 
-- Use Assert.FloatNotEquals instead of Assert.NumericEquals is the numbers you 
-- need to compare have high exponents.
-- Note: NULL is invalid for @ExpectedNotValue. If Assert.FloatNotEquals is
--       called with NULL for @ExpectedNotValue then it will fail with 
--       an ERROR. Use Assert.IsNotNull instead.
-- Note: NULL is invalid for @Tolerance. If Assert.FloatNotEquals is
--       called with NULL for @Tolerance then it will fail with 
--       an ERROR.
-- Note: @Tolerance must be greater or equal than 0. If 
--       Assert.FloatNotEquals is called with a negative number for 
--       @Tolerance then it will fail with an ERROR.
-- Note: If @ActualValue is NULL then Assert.FloatNotEquals will fail.
-- If passes it will record an entry in TestLog.
-- If failes it will record an entry in TestLog and raise an error.
-- =======================================================================
CREATE PROCEDURE Assert.FloatNotEquals
   @ContextMessage      nvarchar(1000),
   @ExpectedNotValue    float(53),
   @ActualValue         float(53),
   @Tolerance           float(53)
AS
BEGIN
   DECLARE @Message     nvarchar(4000)
   DeCLARE @Difference  float(53)
   
   SET @ContextMessage = ISNULL(@ContextMessage, '')

   IF (@ExpectedNotValue IS NULL )
   BEGIN
      SET @Message = 'Invalid call to Assert.FloatNotEquals. [' + @ContextMessage + '] @ExpectedNotValue cannot be NULL. Use Assert.IsNotNull instead.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@Tolerance IS NULL )
   BEGIN
      SET @Message = 'Invalid call to Assert.FloatNotEquals. [' + @ContextMessage + '] @Tolerance cannot be NULL.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@Tolerance <0)
   BEGIN
      SET @Message = 'Invalid call to Assert.FloatNotEquals. [' + @ContextMessage + '] @Tolerance must be a zero or a positive number.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   SET @Difference = @ActualValue - @ExpectedNotValue
   IF (@Difference < 0) SET @Difference = -@Difference

   IF (@Difference > @Tolerance)
   BEGIN
      SET @Message = 
         'Assert.FloatNotEquals passed. [' + @ContextMessage + '] Test value: ' + ISNULL(CONVERT(varchar(50), @ExpectedNotValue, 2), 'NULL') + 
         '. Actual value: ' + ISNULL(CONVERT(varchar(50), @ActualValue, 2), 'NULL') + 
         '. Tolerance: ' + + ISNULL(CONVERT(varchar(50), @Tolerance, 2), 'NULL')
      EXEC Assert.Pass @Message
      RETURN
   END

   SET @Message = 'Assert.FloatNotEquals failed. [' + @ContextMessage + '] Test value: ' + ISNULL(CONVERT(varchar(50), @ExpectedNotValue, 2), 'NULL') + 
         '. Actual value: ' + ISNULL(CONVERT(varchar(50), @ActualValue, 2), 'NULL') + 
         '. Tolerance: ' + + ISNULL(CONVERT(varchar(50), @Tolerance, 2), 'NULL')
   EXEC Assert.Fail @Message

END
GO

-- =======================================================================
-- PROCEDURE: Assert.IsLike
-- Can be called by the test procedures to verify that 
-- @ActualValue matches the pattern specified in @ExpectedLikeValue.
-- The @EscapeCharacter will be used as part of the LIKE operator. 
-- The LIKE expression is written as:  
--       @ActualValue LIKE @ExpectedLikeValue ESCAPE @EscapeCharacter
-- @EscapeCharacter can be use if one needs to escape wildcard characters 
-- like %_[]^ from the pattern. See the LIKE operator documentation.
-- Note: NULL is invalid for @ExpectedLikeValue. If Assert.IsLike is
--       called with NULL for @ExpectedLikeValue then it will fail with 
--       an ERROR. Use Assert.IsNull instead.
-- Note: If @ActualValue IS NULL then Assert.IsLike will fail.
-- If passes it will record an entry in TestLog.
-- If failes it will record an entry in TestLog and raise an error.
-- =======================================================================
CREATE PROCEDURE Assert.IsLike
   @ContextMessage      nvarchar(1000),
   @ExpectedLikeValue   nvarchar(max),
   @ActualValue         nvarchar(max),
   @EscapeCharacter     char = NULL
AS
BEGIN

   DECLARE @Message        nvarchar(4000)
   DECLARE @EscapeMessage  nvarchar(100)

   SET @ContextMessage = ISNULL(@ContextMessage, '')

   IF (@ExpectedLikeValue IS NULL )
   BEGIN
      SET @Message = 'Invalid call to Assert.IsLike. [' + @ContextMessage + '] @ExpectedLikeValue cannot be NULL. Use Assert.IsNull instead.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@ActualValue LIKE @ExpectedLikeValue ESCAPE @EscapeCharacter)
   BEGIN
      SET @Message = 'Assert.IsLike passed. [' + @ContextMessage + '] Test value: ''' + ISNULL(CAST(@ExpectedLikeValue as nvarchar(max)), 'NULL') + '''. Actual value: ''' + ISNULL(CAST(@ActualValue as nvarchar(max)), 'NULL') + ''''
      EXEC Assert.Pass @Message
      RETURN
   END

   SET @EscapeMessage = ''
   IF (@EscapeCharacter IS NOT NULL) SET @EscapeMessage = ' Escape: ' + @EscapeCharacter
   
   SET @Message = 'Assert.IsLike failed. [' + @ContextMessage + ']' + @EscapeMessage + ' Test value: ''' + ISNULL(CAST(@ExpectedLikeValue as nvarchar(max)), 'NULL') + '''. Actual value: ''' + ISNULL(CAST(@ActualValue as nvarchar(max)), 'NULL') + ''''
   EXEC Assert.Fail @Message

END
GO

-- =======================================================================
-- PROCEDURE: Assert.IsNotLike
-- Can be called by the test procedures to verify that 
-- a given character string does NOT match a specified pattern.
-- The @EscapeCharacter will be used as part of the LIKE operator. 
-- The NOT LIKE expression is written as:  
--       @ActualValue NOT LIKE @ExpectedLikeValue ESCAPE @EscapeCharacter
-- @EscapeCharacter can be use if one needs to escape wildcard characters 
-- like %_[]^ from the pattern. See the LIKE operator documentation.
-- Note: NULL is invalid for @ExpectedNotLikeValue. If Assert.IsNotLike is
--       called with NULL for @ExpectedNotLikeValue then it will fail with 
--       an ERROR. Use Assert.IsNotNull instead.
-- Note: If @ActualValue IS NULL then Assert.IsNotLike will fail.
-- If passes it will record an entry in TestLog.
-- If failes it will record an entry in TestLog and raise an error.
-- =======================================================================
CREATE PROCEDURE Assert.IsNotLike
   @ContextMessage         nvarchar(1000),
   @ExpectedNotLikeValue   nvarchar(max),
   @ActualValue            nvarchar(max),
   @EscapeCharacter        char = NULL
AS
BEGIN
   DECLARE @Message        nvarchar(4000)
   DECLARE @EscapeMessage  nvarchar(100)

   SET @ContextMessage = ISNULL(@ContextMessage, '')

   IF (@ExpectedNotLikeValue IS NULL )
   BEGIN
      SET @Message = 'Invalid call to Assert.IsNotLike. [' + @ContextMessage + '] @ExpectedNotLikeValue cannot be NULL. Use Assert.IsNotNull instead.'
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF (@ActualValue NOT LIKE @ExpectedNotLikeValue ESCAPE @EscapeCharacter)
   BEGIN
      SET @Message = 'Assert.IsNotLike passed. [' + @ContextMessage + '] Test value: ''' + ISNULL(CAST(@ExpectedNotLikeValue as nvarchar(max)), 'NULL') + '''. Actual value: ''' + ISNULL(CAST(@ActualValue as nvarchar(max)), 'NULL') + ''''
      EXEC Assert.Pass @Message
      RETURN
   END

   SET @EscapeMessage = ''
   IF (@EscapeCharacter IS NOT NULL) SET @EscapeMessage = ' Escape: ' + @EscapeCharacter

   SET @Message = 'Assert.IsNotLike failed. [' + @ContextMessage + ']' + @EscapeMessage + ' Test value: ''' + ISNULL(CAST(@ExpectedNotLikeValue as nvarchar(max)), 'NULL') + '''. Actual value: ''' + ISNULL(CAST(@ActualValue as nvarchar(max)), 'NULL') + ''''
   EXEC Assert.Fail @Message

END
GO

-- =======================================================================
-- PROCEDURE: Assert.IsNull
-- Can be called by the test procedures to verify that 
-- @ActualValue IS NULL.
-- If passes it will record an entry in TestLog.
-- If failes it will record an entry in TestLog and raise an error.
-- =======================================================================
CREATE PROCEDURE Assert.IsNull
   @ContextMessage      nvarchar(1000),
   @ActualValue         sql_variant
AS
BEGIN
   DECLARE @Message nvarchar(4000)

   SET @ContextMessage = ISNULL(@ContextMessage, '')

   IF (@ActualValue IS NULL)
   BEGIN
      SET @Message = 'Assert.IsNull passed. [' + @ContextMessage + '] Expected value: NULL. Actual value: ''' + ISNULL(CAST(@ActualValue as nvarchar(max)), 'NULL') + ''''
      EXEC Assert.Pass @Message
      RETURN
   END

   SET @Message = 'Assert.IsNull failed. [' + @ContextMessage + '] Expected value: NULL. Actual value: ''' + ISNULL(CAST(@ActualValue as nvarchar(max)), 'NULL') + ''''
   EXEC Assert.Fail @Message

END
GO

-- =======================================================================
-- PROCEDURE: Assert.IsNotNull
-- Can be called by the test procedures to verify that 
-- @ActualValue IS NOT NULL.
-- If passes it will record an entry in TestLog.
-- If failes it will record an entry in TestLog and raise an error.
-- =======================================================================
CREATE PROCEDURE Assert.IsNotNull
   @ContextMessage      nvarchar(1000),
   @ActualValue         sql_variant
AS
BEGIN
   DECLARE @Message nvarchar(4000)

   SET @ContextMessage = ISNULL(@ContextMessage, '')

   IF (@ActualValue IS NOT NULL)
   BEGIN
      SET @Message = 'Assert.IsNotNull passed. [' + @ContextMessage + '] Actual value: ''' + ISNULL(CAST(@ActualValue as nvarchar(max)), 'NULL') + ''''
      EXEC Assert.Pass @Message
      RETURN
   END

   SET @Message = 'Assert.IsNotNull failed. [' + @ContextMessage + '] Actual value: ''' + ISNULL(CAST(@ActualValue as nvarchar(max)), 'NULL') + ''''
   EXEC Assert.Fail @Message

END
GO

-- =======================================================================
-- PROCEDURE: Assert.IsTableNotEmpty
-- Can be called by the test procedures to verify that 
-- #ActualResult is not empty.
-- =======================================================================
CREATE PROCEDURE Assert.IsTableNotEmpty
   @ContextMessage      nvarchar(1000)
AS
BEGIN

   DECLARE @Message     nvarchar(4000)

   SET @ContextMessage = ISNULL(@ContextMessage, '')

   IF (object_id('tempdb..#ActualResult') IS NULL) 
   BEGIN
      SET @Message = 'Assert.IsTableNotEmpty failed. [' + @ContextMessage + '] #ActualResult table was not created.' 
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF EXISTS (SELECT 1 FROM #ActualResult)
   BEGIN
      SET @Message = 'Assert.IsTableNotEmpty passed. [' + @ContextMessage + '] Table #ActualResult has one or more rows.'
      EXEC Assert.Pass @Message
      RETURN
   END

   SET @Message = 'Assert.IsTableNotEmpty failed. [' + @ContextMessage + '] Table #ActualResult is empty.'
   EXEC Assert.Fail @Message

END
GO

-- =======================================================================
-- PROCEDURE: Assert.IsTableEmpty
-- Can be called by the test procedures to verify that 
-- #ActualResult is empty.
-- =======================================================================
CREATE PROCEDURE Assert.IsTableEmpty
   @ContextMessage      nvarchar(1000)
AS
BEGIN

   DECLARE @Message     nvarchar(4000)

   SET @ContextMessage = ISNULL(@ContextMessage, '')

   IF (object_id('tempdb..#ActualResult') IS NULL) 
   BEGIN
      SET @Message = 'Assert.IsTableEmpty failed. [' + @ContextMessage + '] #ActualResult table was not created.' 
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   IF NOT EXISTS (SELECT 1 FROM #ActualResult)
   BEGIN
      SET @Message = 'Assert.IsTableEmpty passed. [' + @ContextMessage + '] Table #ActualResult is empty.'
      EXEC Assert.Pass @Message
      RETURN
   END

   SET @Message = 'Assert.IsTableEmpty failed. [' + @ContextMessage + '] Table #ActualResult has one or more rows.'
   EXEC Assert.Fail @Message

END
GO

-- =======================================================================
-- PROCEDURE: Assert.TableEquals
-- Can be called by the test procedures to verify that tables 
-- #ExpectedResult and #ActualResult have the same entries.
-- =======================================================================
CREATE PROCEDURE Assert.TableEquals
   @ContextMessage      nvarchar(1000),
   @IgnoredColumns      ntext = NULL
AS
BEGIN

   DECLARE @ExpectedRowCount           int
   DECLARE @RunTableComparisonResult   int
   DECLARE @ValidationResult           int
   DECLARE @SchemaError                nvarchar(1000)
   DECLARE @Message                    nvarchar(4000)
   DECLARE @DifferenceRowInfo          nvarchar(max)

   SET @ContextMessage = ISNULL(@ContextMessage, '')

   EXEC @ValidationResult = Internal.BasicTempTableValidation @ContextMessage, @ExpectedRowCount OUT
   IF (@ValidationResult != 0) RETURN  -- an error was already raised

   IF (object_id('tempdb..#DiffRows') IS NULL) 
   BEGIN
      CREATE TABLE #DiffRows(
         ColumnName  sysname NOT NULL,
         ActualValue sql_variant,
         ExpectedValue sql_variant,
      )
   END
   ELSE DELETE FROM #DiffRows

   IF (object_id('tempdb..#SchemaInfoExpectedResults') IS NULL) 
   BEGIN
      CREATE TABLE #SchemaInfoExpectedResults (
         ColumnName           sysname NOT NULL,
         DataTypeName         nvarchar(128) NOT NULL,
         MaxLength            int NOT NULL,
         ColumnPrecision      int NOT NULL,
         ColumnScale          int NOT NULL,
         IsPrimaryKey         bit NOT NULL,
         IsIgnored            bit NOT NULL,
         PkOrdinal            int NULL,
         ColumnCollationName  sysname NULL
      )
   END
   ELSE DELETE FROM #SchemaInfoExpectedResults 
   
   IF (object_id('tempdb..#SchemaInfoActualResults') IS NULL) 
   BEGIN
      CREATE TABLE #SchemaInfoActualResults (
         ColumnName           sysname NOT NULL,
         DataTypeName         nvarchar(128) NOT NULL,
         MaxLength            int NOT NULL,
         ColumnPrecision      int NOT NULL,
         ColumnScale          int NOT NULL,
         IsPrimaryKey         bit NOT NULL,
         IsIgnored            bit NOT NULL,
         PkOrdinal            int NULL,
         ColumnCollationName  sysname NULL
      )
   END
   ELSE DELETE FROM #SchemaInfoActualResults 

   IF (object_id('tempdb..#IgnoredColumns') IS NULL) 
   BEGIN
      CREATE TABLE #IgnoredColumns (ColumnName varchar(500))
   END
   ELSE DELETE FROM #IgnoredColumns

   INSERT INTO #IgnoredColumns(ColumnName) SELECT ListItem FROM Internal.SFN_GetListToTable(@IgnoredColumns)

   EXEC Internal.CollectTempTablesSchema

   EXEC Internal.ValidateTempTablesSchema @SchemaError OUT
   IF (@SchemaError IS NOT NULL)
   BEGIN
      SET @Message = 'Invalid call to Assert.TableEquals. [' + @ContextMessage + '] ' + @SchemaError
      EXEC Internal.LogErrorMessageAndRaiseError @Message
      RETURN
   END

   EXEC @RunTableComparisonResult = Internal.RunTableComparison @DifferenceRowInfo OUT 
   IF (@RunTableComparisonResult != 0) RETURN 
   
   IF (@DifferenceRowInfo IS NOT NULL)
   BEGIN
      SET @Message = 'Assert.TableEquals failed. [' + @ContextMessage + '] #ExpectedResult and #ActualResult do not have the same data. Expected/Actual: ' + @DifferenceRowInfo 
      EXEC Assert.Fail @Message
      RETURN
   END

   SET @Message = 'Assert.TableEquals passed. [' + @ContextMessage + '] ' + CAST(@ExpectedRowCount as varchar) + ' row(s) compared between #ExpectedResult and #ActualResult'
   EXEC Assert.Pass @Message

END
GO


-- =======================================================================
-- END TST API.
-- =======================================================================


-- =======================================================================
-- START External trigger points.
-- These are stored procedures that can be called to trigger TST testing.
-- =======================================================================

-- =======================================================================
-- PROCEDURE: RunSuite
-- It will run all the test procedures in the database given 
-- by @TestDatabaseName and belonging to the suite given by @SuiteName.
-- If @SuiteName IS NULL then it will run all the Test suites 
-- detected in the database given by @TestDatabaseName.
-- =======================================================================
CREATE PROCEDURE Runner.RunSuite
   @TestDatabaseName       sysname,                -- The database that contains the test procedures.
   @SuiteName              sysname,                -- The suite that must be run. If NULL then 
                                                   -- tests in all suites will be run.
   @Verbose                bit = 0,                -- If 1 then the output will contain all suites and tests names and all the log entries.
                                                   -- If 0 then the output will contain all suites and tests names but only the 
                                                   -- log entries indicating failures.
   @ResultsFormat          varchar(10) = 'Text',   -- Indicates if the format in which the results will be printed.
                                                   -- See the coments at the begining of the file under section 'Results Format'
   @NoTimestamp            bit = 0,                -- Indicates that no timestamp or duration info should be printed in results output
   @CleanTemporaryData     bit = 1,                -- Indicates if the temporary tables should be cleaned at the end.
   @TestSessionId          int = NULL OUT,         -- At return will identify the test session 
   @TestSessionPassed      bit = NULL OUT          -- At return will indicate if all tests passed or not.
AS
BEGIN

   DECLARE @PrepareResult           int
   DECLARE @TestProcedurePrefix     varchar(100)

   SET NOCOUNT ON

   IF (@TestDatabaseName IS NULL) 
   BEGIN
      RAISERROR('Invalid call to RunSuite. @TestDatabaseName cannot be NULL.', 16, 1)
      RETURN 1
   END      

   BEGIN
      CREATE TABLE #Tmp_CrtSessionInfo (
         TestSessionId                 int NOT NULL,
         TestId                        int NOT NULL,
         Stage                         char NOT NULL,       -- '-' Outside of any test
                                                            -- 'A' Test session setup stage
                                                            -- 'S' Setup stage
                                                            -- 'T' Test stage
                                                            -- 'X' Teardown stage
                                                            -- 'Z' Test session teardown stage
         ExpectedErrorNumber           int NULL,
         ExpectedErrorMessage          nvarchar(2048),
         ExpectedErrorProcedure        nvarchar(126),
         ExpectedErrorContextMessage   nvarchar(1000)
      )
   END
   
   EXEC @PrepareResult = Internal.PrepareTestSession @TestDatabaseName, @TestSessionId OUTPUT
   
   IF (@PrepareResult = 0)
   BEGIN
      SELECT @TestProcedurePrefix = Internal.SFN_GetTestProcedurePrefix(@TestDatabaseName)
      EXEC @PrepareResult = Internal.PrepareTestSessionInformation @TestSessionId, @TestProcedurePrefix, @TestDatabaseName, @SuiteName, NULL
      IF (@PrepareResult = 0)
      BEGIN
         EXEC Internal.RunTestSession @TestSessionId, @SuiteName
      END
   END
   
   -- Note: if @PrepareResult is 0 then we already have errors in the TestLog table.

   SET @TestSessionPassed = 1
   IF EXISTS (SELECT 1 FROM Data.TestLog WHERE TestSessionId = @TestSessionId AND EntryType IN ('F', 'E')) SET @TestSessionPassed = 0
   IF EXISTS (SELECT 1 FROM Data.SystemErrorLog WHERE TestSessionId = @TestSessionId) SET @TestSessionPassed = 0

   UPDATE Data.TestSession SET TestSessionFinish = GETDATE()
  
   EXEC Internal.PostTestRun @TestSessionId, @ResultsFormat, @NoTimestamp, @Verbose, @CleanTemporaryData
   
END
GO

-- =======================================================================
-- PROCEDURE: RunTest
-- It will run the test procedure with the name given by @TestName
-- in the database given by @TestDatabaseName.
-- =======================================================================
CREATE PROCEDURE Runner.RunTest
   @TestDatabaseName    sysname,                   -- The database that contains the test procedures.
   @TestName            sysname,                   -- The test that must be run.
   @Verbose             bit = 0,                   -- If 1 then the output will contain all suites and tests names and all the log entries.
                                                   -- If 0 then the output will contain all suites and tests names but only the 
                                                   -- log entries indicating failures.
   @ResultsFormat       varchar(10) = 'Text',      -- Indicates if the format in which the results will be printed.
                                                   -- See the coments at the begining of the file under section 'Results Format'
   @NoTimestamp         bit = 0,                   -- Indicates that no timestamp or duration info should be printed in results output
   @CleanTemporaryData  bit = 1,                   -- Indicates if the temporary tables should be cleaned at the end.
   @TestSessionId       int = NULL OUT,            -- At return will identify the test session 
   @TestSessionPassed   bit = NULL OUT             -- At return will indicate if all tests passedor not.
AS
BEGIN

   DECLARE @PrepareResult           int
   DECLARE @TestProcedurePrefix     varchar(100)

   SET NOCOUNT ON

   IF (@TestDatabaseName IS NULL) 
   BEGIN
      RAISERROR('Invalid call to RunTest. @TestDatabaseName cannot be NULL.', 16, 1)
      RETURN 1
   END

   BEGIN
      CREATE TABLE #Tmp_CrtSessionInfo (
         TestSessionId                 int NOT NULL,
         TestId                        int NOT NULL,
         Stage                         char NOT NULL,       -- '-' Outside of any test
                                                            -- 'S' Setup stage
                                                            -- 'T' Test stage
                                                            -- 'X' Teardown stage
         ExpectedErrorNumber           int NULL,
         ExpectedErrorMessage          nvarchar(2048),
         ExpectedErrorProcedure        nvarchar(126),
         ExpectedErrorContextMessage   nvarchar(1000)
      )
   END

   EXEC @PrepareResult = Internal.PrepareTestSession @TestDatabaseName, @TestSessionId OUTPUT
   IF (@PrepareResult = 0)
   BEGIN
      SELECT @TestProcedurePrefix = Internal.SFN_GetTestProcedurePrefix(@TestDatabaseName)
      -- PrepareTestSessionInformation will colect data only about the given test so we can 
      -- call RunTestSession with NULL for @SuiteName 
      EXEC @PrepareResult = Internal.PrepareTestSessionInformation @TestSessionId, @TestProcedurePrefix, @TestDatabaseName, NULL, @TestName
      IF (@PrepareResult = 0)
      BEGIN
         EXEC Internal.RunTestSession @TestSessionId, NULL
      END
   END
   
   -- Note: if @PrepareResult is 0 then we already have errors in the TestLog table.

   SET @TestSessionPassed = 1
   IF EXISTS (SELECT 1 FROM Data.TestLog WHERE TestSessionId = @TestSessionId AND EntryType IN ('F', 'E')) SET @TestSessionPassed = 0
   IF EXISTS (SELECT 1 FROM Data.SystemErrorLog WHERE TestSessionId = @TestSessionId) SET @TestSessionPassed = 0

   UPDATE Data.TestSession SET TestSessionFinish = GETDATE()

   EXEC Internal.PostTestRun @TestSessionId, @ResultsFormat, @NoTimestamp, @Verbose, @CleanTemporaryData
   
END
GO

-- =======================================================================
-- PROCEDURE: RunAll
-- It will run all the test procedures in the database given 
-- by @TestDatabaseName.
-- =======================================================================
CREATE PROCEDURE Runner.RunAll
   @TestDatabaseName    sysname,                   -- The database that contains the test procedures.
   @Verbose             bit = 0,                   -- If 1 then the output will contain all suites and tests names and all the log entries.
                                                   -- If 0 then the output will contain all suites and tests names but only the 
                                                   -- log entries indicating failures.
   @ResultsFormat       varchar(10) = 'Text',      -- Indicates if the format in which the results will be printed.
                                                   -- See the coments at the begining of the file under section 'Results Format'
   @NoTimestamp         bit = 0,                   -- Indicates that no timestamp or duration info should be printed in results output
   @CleanTemporaryData  bit = 1,                   -- Indicates if the temporary tables should be cleaned at the end.
   @TestSessionId       int = NULL OUT,            -- At return will identify the test session 
   @TestSessionPassed   bit = NULL OUT             -- At return will indicate if all tests passedor not.
AS
BEGIN

   IF (@TestDatabaseName IS NULL) 
   BEGIN
      RAISERROR('Invalid call to RunAll. @TestDatabaseName cannot be NULL.', 16, 1)
      RETURN 1
   END
   
   SET NOCOUNT ON
   EXEC Runner.RunSuite @TestDatabaseName, NULL,  @Verbose, @ResultsFormat, @NoTimestamp, @CleanTemporaryData, @TestSessionId OUT, @TestSessionPassed OUT
END
GO
-- =======================================================================
-- END External trigger points.
-- =======================================================================

USE tempdb
