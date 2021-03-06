--===================================================================
-- FILE: SetTSTCheckMaster.sql
-- This script will setup one of the databases used to test the 
-- TST infrastructure.
-- Tests contained here will validate the TST features. These
-- tests will exercise TST against suites and tests contained 
-- in other databases like TSTCheck or TSTCheckTran and validate 
-- the outcome.
-- ==================================================================

USE tempdb
GO


-- =======================================================================
-- Creates the TSTCheckMaster. If already exists then drops it first.
-- =======================================================================
IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'TSTCheckMaster')
BEGIN
   DROP DATABASE TSTCheckMaster
END

CREATE DATABASE TSTCheckMaster
GO

USE TSTCheckMaster
GO

-- =======================================================================
-- TSTConfig. TST will call this at the start of the test session 
-- to allow the test client to configure parameters
-- =======================================================================
CREATE PROCEDURE dbo.TSTConfig
AS
BEGIN

   -- Most of the tests in this script will invoke TST runner APIS (TST.dbo.RunXXX). 
   -- The TST runner APIS will begin and rollback a transaction. 
   -- In the same time the tests in this script are invoked by a TST runner API. 
   -- Hence we will get into a situation with nested transactions. To avoid this 
   -- We will tell the TST instance that invokes the scripts here to NOT use transactions.
   EXEC TST.Utils.SetConfiguration @ParameterName='UseTSTRollback', @ParameterValue='0', @Scope='All'
      
END
GO

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- START Helper functions and stored procedures
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


-- ==============================================================================
-- Breaks an array of comma separated items into elements in a dataset.
-- ==============================================================================
CREATE FUNCTION dbo.StringToDataset(@ItemsArray varchar(max))
RETURNS @ItemsDataset TABLE 
(
    Item varchar(255)
)
AS
BEGIN

   DECLARE @ItemLength           int

   WHILE (LEN(@ItemsArray) > 0)
   BEGIN

      SET @ItemLength = CHARINDEX(',', @ItemsArray) - 1
      IF (@ItemLength > 0) 
      BEGIN
         INSERT INTO @ItemsDataset(Item) VALUES (SUBSTRING(@ItemsArray, 1, @ItemLength) )
         SET @ItemsArray = RIGHT(@ItemsArray, LEN(@ItemsArray) - @ItemLength - 1)
      END
      ELSE
      BEGIN
         INSERT INTO @ItemsDataset(Item) VALUES (@ItemsArray)
         SET @ItemsArray = ''
      END

   END
   
   RETURN 
   
END
GO

-- ==============================================================================
-- Validates that for the test session given by @TestSessionId 
-- there are no suites, tests or entries in TestLog
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateNoSuitesTestsOrTestLog
   @TestSessionId          int
AS
BEGIN
   
   DECLARE @RowCount             int
   
   SELECT @RowCount = COUNT(*) FROM TST.Data.Suite WHERE TestSessionId=@TestSessionId
   EXEC TST.Assert.Equals 'No suite should be recorded for this test session', 0, @RowCount

   SELECT @RowCount = COUNT(*) FROM TST.Data.Test WHERE TestSessionId=@TestSessionId
   EXEC TST.Assert.Equals 'No test should be recorded for this test session', 0, @RowCount

   SELECT @RowCount = COUNT(*) FROM TST.Data.TestLog WHERE TestSessionId=@TestSessionId
   EXEC TST.Assert.Equals 'No test log should be recorded for this test session', 0, @RowCount
   
END
GO

-- ==============================================================================
-- Validates that for the test session given by @TestSessionId 
-- there is one system error with the message given by @ExpectedErrorMessage
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateOneSystemError
   @TestSessionId          int,
   @ExpectedErrorMessage   varchar(4000)
AS
BEGIN
   
   DECLARE @RowCount             int
   DECLARE @ActualErrorMessage   varchar(4000)
   
   SELECT @RowCount = COUNT(*) FROM TST.Data.SystemErrorLog WHERE TestSessionId=@TestSessionId
   EXEC TST.Assert.Equals 'Only one entry must be recorded in TST.Data.SystemErrorLog', 1, @RowCount
   
   SELECT @ActualErrorMessage = LogMessage FROM TST.Data.SystemErrorLog WHERE TestSessionId=@TestSessionId
   EXEC TST.Assert.Equals 'System Error Message', @ExpectedErrorMessage, @ActualErrorMessage
   
END
GO

-- ==============================================================================
-- Validates that for the test session given by @TestSessionId 
-- there are no system errors.
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateNoSystemErrors
   @TestSessionId int
AS
BEGIN
   
   DECLARE @RowCount int
   
   SELECT @RowCount = COUNT(*) FROM TST.Data.SystemErrorLog WHERE TestSessionId=@TestSessionId
   EXEC TST.Assert.Equals 'No system errors must be recorded in TST.Data.SystemErrorLog', 0, @RowCount
   
END
GO

-- ==============================================================================
-- Validates that the test session given by @TestSessionId 
-- exists in the TST.Data.TestSession table
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateTestSession
   @TestSessionId int
AS
BEGIN
   
   DECLARE @RowCount int
   
   SELECT @RowCount = COUNT(*) FROM TST.Data.TestSession WHERE TestSessionId=@TestSessionId
   EXEC TST.Assert.Equals 'The test session must be recorded in TST.Data.TestSession', 1, @RowCount
   
END
GO

-- ==============================================================================
-- Validates that for the test session given by @TestSessionId, in 
-- TST.Data.Suite there is only one suite and it has the name given by @SuiteName.
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateOnlyOneSuiteExists
   @TestSessionId    int,
   @SuiteName        sysname
AS
BEGIN

   DECLARE @RowCount int
   DECLARE @ContextMessage    varchar(1000)

   SELECT @RowCount = COUNT(*) FROM TST.Data.Suite WHERE TestSessionId=@TestSessionId AND (SuiteName=@SuiteName OR (SuiteName IS NULL AND @SuiteName IS NULL))
   SET @ContextMessage = 'There must be only one suite with the name "' + ISNULL(@SuiteName, '[null]') + '" recorded'
   EXEC TST.Assert.Equals @ContextMessage, 1, @RowCount
   
   SELECT @RowCount = COUNT(*) FROM TST.Data.Suite WHERE 
      TestSessionId=@TestSessionId 
      AND (SuiteName = @SuiteName OR (SuiteName IS NULL AND @SuiteName IS NULL) )
   SET @ContextMessage = 'The expected suite: "' + ISNULL(@SuiteName, '[null]') + '" is recorded'
   EXEC TST.Assert.Equals @ContextMessage, 1, @RowCount

END
GO

-- ==============================================================================
-- For the test session given by @TestSessionId:
-- If the @SProcName IS NOT NULL then verifies the existance of the sproc with the 
-- name given by @SProcName and type given by @SProcType.
-- If the @SProcName IS NULL then it verifies that no sproc with the 
-- type given by @SProcType does exist.
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateOnlyOneSProcExists
   @TestSessionId    int,
   @SProcName        sysname,
   @SProcType        varchar(10)
AS
BEGIN
   
   DECLARE @RowCount          int
   DECLARE @ContextMessage    varchar(1000)

   IF @SProcName IS NOT NULL
   BEGIN
      SELECT @RowCount = COUNT(*) FROM TST.Data.Test WHERE 
         TestSessionId = @TestSessionId 
         AND SProcName = @SProcName
         AND SProcType = @SProcType
         
      SET @ContextMessage = 'The expected test: "' + @SProcName + '" with type [' + @SProcType + '] is recorded'
      EXEC TST.Assert.Equals @ContextMessage, 1, @RowCount
   END
   ELSE
   BEGIN
      SELECT @RowCount = COUNT(*) FROM TST.Data.Test WHERE 
         TestSessionId = @TestSessionId 
         AND SProcType = @SProcType
         
      SET @ContextMessage = 'No sproc with type ' + @SProcType + ' should be recorded'
      EXEC TST.Assert.Equals @ContextMessage, 0, @RowCount
   END

END
GO

-- ==============================================================================
-- Validates that the list of tests in the test session given by @TestSessionId and 
-- having the SProcType given by @SProcType, is identical to the list in @SProcsNames.
-- Also validates that all have the type given by @SProcType.
-- @SProcsNames is a string of items separated by ','
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateOnlyGivenTestExists
   @TestSessionId    int,
   @SProcsNames      varchar(max),
   @SProcType        varchar(10)
AS
BEGIN
   
   DECLARE @RowInvalidProcType   int
   DECLARE @RowInvalidProc       int
   DECLARE @RowNotFoundProc      int

   DECLARE @SProcNamesTable TABLE  (Item varchar(255))
   INSERT INTO @SProcNamesTable SELECT * FROM  dbo.StringToDataset(@SProcsNames)

   -- Determines the number of entries in TST.Data.Test that don't have the same SProcType as given by @SProcType
   SELECT @RowInvalidProcType = COUNT(*) 
   FROM TST.Data.Test 
   WHERE Test.TestSessionId = @TestSessionId AND SProcType != @SProcType
   EXEC TST.Assert.Equals 'ValidateOnlyGivenTestExists: Only tests of a given type are accepted', 0, @RowInvalidProcType
   
   -- Determines the number of sprocs stored in TST.Data.Test that are not in @SProcsNames
   SELECT @RowInvalidProc = COUNT(*) 
   FROM TST.Data.Test 
   WHERE 
      Test.TestSessionId = @TestSessionId
      AND Test.SProcName NOT IN (SELECT Item FROM @SProcNamesTable)

   EXEC TST.Assert.Equals 'ValidateOnlyGivenTestExists: Unexpected rows found in TST.Data.Test', 0, @RowInvalidProc 

   
   -- Determines the number of sprocs from @SProcsNames that are not stored in TST.Data.Test
   SELECT @RowNotFoundProc = COUNT(*) 
   FROM @SProcNamesTable
   WHERE 
      Item NOT IN ( SELECT SProcName FROM TST.Data.Test WHERE Test.TestSessionId = @TestSessionId)

   EXEC TST.Assert.Equals 'ValidateOnlyGivenTestExists: Not all expected rows were found in TST.Data.Test', 0, @RowNotFoundProc

END
GO

-- ==============================================================================
-- Validates that the list of tests in the test session given by @TestSessionId and 
-- having the SProcType given by @SProcType, is identical to the list in @SProcsNames.
-- @SProcsNames is a string of items separated by ','
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateOnlyGivenTestExistsByType
   @TestSessionId    int,
   @SProcsNames      varchar(max),
   @SProcType        varchar(10)
AS
BEGIN
   
   DECLARE @RowInvalidProcType   int
   DECLARE @RowInvalidProc       int
   DECLARE @RowNotFoundProc      int

   DECLARE @SProcNamesTable TABLE  (Item varchar(255))
   INSERT INTO @SProcNamesTable SELECT * FROM  dbo.StringToDataset(@SProcsNames)

   -- Determines the number of sprocs stored in TST.Data.Test that are not in @SProcsNames
   SELECT @RowInvalidProc = COUNT(*) 
   FROM TST.Data.Test 
   WHERE 
      Test.TestSessionId = @TestSessionId
      AND Test.SProcType = @SProcType
      AND Test.SProcName NOT IN (SELECT Item FROM @SProcNamesTable)

   EXEC TST.Assert.Equals 'ValidateOnlyGivenTestExistsByType: Unexpected rows found in TST.Data.Test', 0, @RowInvalidProc 

   
   -- Determines the number of sprocs from @SProcsNames that are not stored in TST.Data.Test
   SELECT @RowNotFoundProc = COUNT(*) 
   FROM @SProcNamesTable
   WHERE 
      Item NOT IN ( SELECT SProcName FROM TST.Data.Test WHERE Test.TestSessionId = @TestSessionId AND Test.SProcType = @SProcType)

   EXEC TST.Assert.Equals 'ValidateOnlyGivenTestExistsByType: Not all expected rows were found in TST.Data.Test', 0, @RowNotFoundProc

END
GO

-- ==============================================================================
-- Validates that for the test session given by @TestSessionId, in 
-- TST.Data.TestLog there is only one entry with the given type and LogMessage
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateOnlyOneTestLogEntryExists
   @TestSessionId          int,
   @ExpectedEntryType      char,
   @ExpectedLogMessage     nvarchar(4000)
AS
BEGIN
   
   DECLARE @RowCount          int
   DECLARE @ActualEntryType   char
   DECLARE @ActualLogMessage  nvarchar(4000)

   SELECT @RowCount = COUNT(*) FROM TST.Data.TestLog WHERE TestSessionId=@TestSessionId
   EXEC TST.Assert.Equals 'There must be only one test log entry recorded', 1, @RowCount
   
   SELECT @ActualEntryType = EntryType, @ActualLogMessage = LogMessage FROM TST.Data.TestLog WHERE TestSessionId  = @TestSessionId 
   EXEC TST.Assert.Equals 'ActualLogMessage', @ExpectedLogMessage, @ActualLogMessage
   EXEC TST.Assert.Equals 'EntryType', @ExpectedEntryType, @ActualEntryType

END
GO

-- ==============================================================================
-- Validates that for the test session given by @TestSessionId, 
-- and for the test given by @TestName in 
-- TST.Data.TestLog there is only one entry that has the type given 
-- by @ExpectedEntryType and the text given by @ExpectedLogMessage
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateOnlyOneTestLogEntryExistsForTest
   @TestSessionId          int,
   @TestName               sysname,
   @ExpectedEntryType      char,
   @ExpectedLogMessage     nvarchar(4000)
AS
BEGIN
   
   DECLARE @RowCount          int
   DECLARE @TestId            int
   DECLARE @ActualEntryType   char
   DECLARE @ActualLogMessage  nvarchar(4000)
   DECLARE @ContextMessage       varchar(4000)

   SELECT @TestId = MAX(TestLog.TestId), @RowCount = COUNT(*) FROM TST.Data.TestLog 
   INNER JOIN TST.Data.Test ON Test.TestId = TestLog.TestId
   WHERE TestLog.TestSessionId=@TestSessionId AND Test.SProcName = @TestName

   SET @ContextMessage = 'There must be only one test log entry recorded for the test ''' + @TestName + ''''
   EXEC TST.Assert.Equals @ContextMessage, 1, @RowCount
   
   SELECT @ActualEntryType = EntryType, @ActualLogMessage = LogMessage FROM TST.Data.TestLog WHERE TestId = @TestId
   EXEC TST.Assert.Equals 'ActualLogMessage', @ExpectedLogMessage, @ActualLogMessage
   EXEC TST.Assert.Equals 'EntryType', @ExpectedEntryType, @ActualEntryType

END
GO

-- ==============================================================================
-- Validates that for the test session given by @TestSessionId, 
-- and for the test given by @TestName in 
-- TST.Data.TestLog there is only one entry that has the type given 
-- by @ExpectedEntryType where the LogMessage is LIKE @ExpectedLogMessage
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest
   @TestSessionId          int,
   @TestName               sysname,
   @ExpectedEntryType      char,
   @ExpectedLogMessage     nvarchar(4000),
   @EscapeCharacter        char = NULL
AS
BEGIN
   
   DECLARE @RowCount          int
   DECLARE @TestId            int
   DECLARE @ActualEntryType   char
   DECLARE @ActualLogMessage  nvarchar(4000)
   DECLARE @ContextMessage       varchar(4000)

   SELECT @TestId = MAX(TestLog.TestId), @RowCount = COUNT(*) FROM TST.Data.TestLog 
   INNER JOIN TST.Data.Test ON Test.TestId = TestLog.TestId
   WHERE TestLog.TestSessionId=@TestSessionId AND Test.SProcName = @TestName

   SET @ContextMessage = 'There must be only one test log entry recorded for the test ''' + @TestName + ''''
   EXEC TST.Assert.Equals @ContextMessage, 1, @RowCount
   
   SELECT @ActualEntryType = EntryType, @ActualLogMessage = LogMessage FROM TST.Data.TestLog WHERE TestId = @TestId
   EXEC TST.Assert.IsLike   'ActualLogMessage', @ExpectedLogMessage, @ActualLogMessage, @EscapeCharacter
   EXEC TST.Assert.Equals 'EntryType', @ExpectedEntryType, @ActualEntryType

END
GO

-- ==============================================================================
-- Validates that for the test session given by @TestSessionId, in 
-- TST.Data.TestLog there is only one entry with the given type 
-- and where the LogMessage is LIKE @ExpectedLogMessage
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateOnlyOneTestLogEntryLikeExists
   @TestSessionId          int,
   @ExpectedEntryType      char,
   @ExpectedLogMessage     nvarchar(4000),
   @EscapeCharacter        char = NULL
AS
BEGIN
   
   DECLARE @RowCount          int
   DECLARE @ActualEntryType   char
   DECLARE @ActualLogMessage  nvarchar(4000)

   SELECT @RowCount = COUNT(*) FROM TST.Data.TestLog WHERE TestSessionId=@TestSessionId
   EXEC TST.Assert.Equals 'There must be only one test log entry recorded', 1, @RowCount
   
   SELECT @ActualEntryType = EntryType, @ActualLogMessage = LogMessage FROM TST.Data.TestLog WHERE TestSessionId  = @TestSessionId 
   EXEC TST.Assert.IsLike   'ActualLogMessage', @ExpectedLogMessage, @ActualLogMessage, @EscapeCharacter
   EXEC TST.Assert.Equals 'EntryType', @ExpectedEntryType, @ActualEntryType

END
GO

CREATE PROCEDURE dbo.ValidateLogEntryCountForTestSession
   @TestSessionId          int,
   @ExpectedLogEntryCount  int
AS
BEGIN

   DECLARE @ContextMessage       varchar(4000)
   DECLARE @ActualLogEntryCount  int

   SELECT @ActualLogEntryCount = COUNT(*) 
   FROM TST.Data.TestLog
   INNER JOIN TST.Data.Test ON Test.TestId = TestLog.TestId
   WHERE Test.TestSessionId = @TestSessionId

   SET @ContextMessage = 'Log entry count for Test Session' + CAST(@TestSessionId AS varchar)
   EXEC TST.Assert.Equals @ContextMessage, @ExpectedLogEntryCount, @ActualLogEntryCount

END
GO

CREATE PROCEDURE dbo.ValidateLogEntryCountForSproc
   @TestSessionId          int,
   @SProcName              sysname,
   @ExpectedLogEntryCount  int
AS
BEGIN

   DECLARE @ContextMessage       varchar(4000)
   DECLARE @ActualLogEntryCount  int

   SELECT @ActualLogEntryCount = COUNT(*) 
   FROM TST.Data.TestLog
   INNER JOIN TST.Data.Test ON Test.TestId = TestLog.TestId
   WHERE 
      Test.TestSessionId = @TestSessionId
      AND Test.SProcName = @SProcName

   SET @ContextMessage = 'Log entry count for SProc ''' + @SProcName + ''''
   EXEC TST.Assert.Equals @ContextMessage, @ExpectedLogEntryCount, @ActualLogEntryCount

END
GO

-- ==============================================================================
-- Validates that for the test session given by @TestSessionId and for the test 
-- given by SProcName, in the TST.Data.TestLog table the message with the 
-- index @LogIndex (1 based) has the type given by @ExpectedLogType and the
-- text given by @ExpectedLogMessage.
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateLogEntryForSprocByIndex
   @TestSessionId          int,
   @SProcName              sysname,
   @LogIndex               int,
   @ExpectedLogType        char,             -- Indicates the type of log entry:
                                             --    'P' - Pass
                                             --    'L' - Log
                                             --    'F' - Fail
                                             --    'E' - Error
   @ExpectedLogMessage     nvarchar(4000)
AS
BEGIN

   DECLARE @ContextMessage       varchar(4000)
   DECLARE @ActualLogMessage     varchar(4000)
   DECLARE @ActualLogMessageType char

   SELECT 
      @ActualLogMessage       = MessageList.LogMessage,
      @ActualLogMessageType   = MessageList.EntryType
   FROM  (
            SELECT LogMessage, EntryType, ROW_NUMBER() OVER (PARTITION BY Test.TestSessionId ORDER BY LogEntryId) AS LogIndex
            FROM TST.Data.TestLog
            INNER JOIN TST.Data.Test ON Test.TestId = TestLog.TestId
            WHERE 
               Test.TestSessionId = @TestSessionId
               AND Test.SProcName = @SProcName
         ) AS MessageList
   WHERE MessageList.LogIndex = @LogIndex 

   SET @ContextMessage = 'Log message #' + CAST(@LogIndex AS varchar) + ' for SProc ''' + @SProcName + ''''
   EXEC TST.Assert.Equals @ContextMessage, @ExpectedLogMessage, @ActualLogMessage

   SET @ContextMessage = 'Log message #' + CAST(@LogIndex AS varchar) + ' for SProc ''' + @SProcName + ''' must have the type ''' + @ExpectedLogType + ''''
   EXEC TST.Assert.Equals @ContextMessage, @ExpectedLogType, @ActualLogMessageType
   
END
GO

-- ==============================================================================
-- Validates that for the test session given by @TestSessionId and for the test 
-- given by SProcName, in the TST.Data.TestLog table the message with the 
-- index @LogIndex (1 based) has the type given by @ExpectedLogType and the
-- text has the pattern (as define by the LIKE operator) given by 
-- @ExpectedLogMessage.
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateLogEntryLikeForSprocByIndex
   @TestSessionId          int,
   @SProcName              sysname,
   @LogIndex               int,
   @ExpectedLogType        char,             -- Indicates the type of log entry:
                                             --    'P' - Pass
                                             --    'L' - Log
                                             --    'F' - Fail
                                             --    'E' - Error
   @ExpectedLogMessage     nvarchar(4000),
   @EscapeCharacter        char = NULL
AS
BEGIN

   DECLARE @ContextMessage       varchar(4000)
   DECLARE @ActualLogMessage     varchar(4000)
   DECLARE @ActualLogMessageType char

   SELECT 
      @ActualLogMessage       = MessageList.LogMessage,
      @ActualLogMessageType   = MessageList.EntryType
   FROM  (
            SELECT LogMessage, EntryType, ROW_NUMBER() OVER (PARTITION BY Test.TestSessionId ORDER BY LogEntryId) AS LogIndex
            FROM TST.Data.TestLog
            INNER JOIN TST.Data.Test ON Test.TestId = TestLog.TestId
            WHERE 
               Test.TestSessionId = @TestSessionId
               AND Test.SProcName = @SProcName
         ) AS MessageList
   WHERE MessageList.LogIndex = @LogIndex 

   SET @ContextMessage = 'Log Message #' + CAST(@LogIndex AS varchar) + ' for SProc ''' + @SProcName + ''''
   EXEC TST.Assert.IsLike @ContextMessage, @ExpectedLogMessage, @ActualLogMessage, @EscapeCharacter

   SET @ContextMessage = 'Log message #' + CAST(@LogIndex AS varchar) + ' for SProc ''' + @SProcName + ''' must have the type ''' + @ExpectedLogType + ''''
   EXEC TST.Assert.Equals @ContextMessage, @ExpectedLogType, @ActualLogMessageType

END
GO


-- ==============================================================================
-- Validates the TST info resulted after a single test is run. 
-- Only the given test should be recorded. No Suite, setup or teardown is expeced. 
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateTestButNoSuiteSetupTeardownRecorded
   @TestSessionId             int,
   @SProcName                 sysname
AS
BEGIN

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName=NULL
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName=@SProcName  , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName=NULL        , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName=NULL        , @SProcType='Teardown'

END
GO

-- ==============================================================================
-- Validates the TST info resulted after a single test is run. That test is 
-- expected to produce only one log entry.
-- ==============================================================================
CREATE PROCEDURE dbo.ValidateSingleTestResults
   @TestSessionId             int,
   @SuiteName                 sysname,
   @SProcName                 sysname,
   @SProcSetupName            sysname = NULL,
   @SProcTeardownName         sysname = NULL,
   @ExpectedEntryType         char,
   @ExpectedLogMessage        nvarchar(4000) = NULL,
   @ExpectedLogMessageLike    nvarchar(4000) = NULL,
   @EscapeCharacter           char = NULL
AS
BEGIN

   DECLARE @RowCount             int
   DECLARE @ExpectedSprocCount   int

   IF (@ExpectedLogMessage IS NOT NULL AND @ExpectedLogMessageLike IS NOT NULL)
   BEGIN
      EXEC TST.Assert.Fail 'Invalid call to ValidateSingleTestResults. @ExpectedLogMessage and @ExpectedLogMessageLike cannot be both specified.' 
      RETURN 
   END

   IF (@ExpectedLogMessage IS NULL AND @ExpectedLogMessageLike IS NULL)
   BEGIN
      EXEC TST.Assert.Fail 'Invalid call to ValidateSingleTestResults. @ExpectedLogMessage and @ExpectedLogMessageLike cannot be both NULL.' 
      RETURN 
   END

   SET @ExpectedSprocCount = 0
   IF (@SProcName          IS NOT NULL) SET @ExpectedSprocCount = @ExpectedSprocCount + 1
   IF (@SProcSetupName     IS NOT NULL) SET @ExpectedSprocCount = @ExpectedSprocCount + 1
   IF (@SProcTeardownName  IS NOT NULL) SET @ExpectedSprocCount = @ExpectedSprocCount + 1

   SELECT @RowCount = COUNT(*) FROM TST.Data.Test WHERE TestSessionId = @TestSessionId 
   EXEC TST.Assert.Equals 'SProc count', @ExpectedSprocCount, @RowCount

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName=@SuiteName
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName=@SProcName, @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName=@SProcSetupName, @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName=@SProcTeardownName, @SProcType='Teardown'
   
   IF (@ExpectedLogMessage IS NOT NULL)
   BEGIN
      EXEC dbo.ValidateOnlyOneTestLogEntryExists  @TestSessionId=@TestSessionId, @ExpectedEntryType=@ExpectedEntryType, @ExpectedLogMessage=@ExpectedLogMessage
   END
   
   IF (@ExpectedLogMessageLike IS NOT NULL)
   BEGIN
      EXEC dbo.ValidateOnlyOneTestLogEntryLikeExists  @TestSessionId=@TestSessionId, @ExpectedEntryType=@ExpectedEntryType, @ExpectedLogMessage=@ExpectedLogMessageLike, @EscapeCharacter=@EscapeCharacter
   END
   
END
GO

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- END Helper functions and stored procedures
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- START test stored procedures
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- =======================================================================
-- Test TST.dbo.SFN_SProcExists when called on an existent stored procedure
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SFN_SProcExistsTrue
AS 
BEGIN

   DECLARE @ResultValue bit
   
   EXEC @ResultValue = TST.Internal.SFN_SProcExists 'TSTCheck', 'ExistingSProc'
   EXEC TST.Assert.Equals 'SFN_SProcExists called on existing sproc', 1, @ResultValue

END
GO

-- =======================================================================
-- Test TST.dbo.SFN_SProcExists when called on an existent function
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SFN_SProcExistsFcFalse
AS 
BEGIN

   DECLARE @ResultValue bit
   
   EXEC @ResultValue = TST.Internal.SFN_SProcExists 'TSTCheck', 'ExistingFc'
   
   -- Since ExistingFc is a function not an sproc we expect a return of 0
   EXEC TST.Assert.Equals 'SFN_SProcExists called on existing function', 0, @ResultValue

END
GO

-- =======================================================================
-- Test TST.dbo.SFN_SProcExists when called on an nonexistent sproc
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SFN_SProcExistsFalse
AS 
BEGIN

   DECLARE @ResultValue bit
   
   EXEC @ResultValue = TST.Internal.SFN_SProcExists 'TSTCheck', 'NonExistingSProc'
   
   -- Since ExistingFc is a function not an sproc we expect a return of 0
   EXEC TST.Assert.Equals 'SFN_SProcExists called on existing function', 0, @ResultValue

END
GO

-- =======================================================================
-- Test TST.Data.SuiteExists when called on an existent suite
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SuiteExistsTrue
AS 
BEGIN

   DECLARE @SuiteExists bit
   
   EXEC TST.Internal.SuiteExists 'TSTCheck', 'Suite1', 'SQLTest_', @SuiteExists OUT
   EXEC TST.Assert.Equals 'SuiteExists called on an existing suite', 1, @SuiteExists 

END
GO

-- =======================================================================
-- Test TST.Data.SuiteExists when called on an nonexistent suite
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SuiteExistsFalse
AS 
BEGIN

   DECLARE @SuiteExists bit
   
   EXEC TST.Internal.SuiteExists 'TSTCheck', 'NonExistingSuite', 'SQLTest_', @SuiteExists OUT
   EXEC TST.Assert.Equals 'SuiteExists called on a non existing suite', 0, @SuiteExists 

END
GO


CREATE PROCEDURE dbo.SQLTest_GetListToTable#NoList
AS 
BEGIN

   DECLARE @Count int
   DECLARE @ListItems TABLE (ListItem varchar(500) PRIMARY KEY NOT NULL)
   
   INSERT INTO @ListItems SELECT * FROM TST.Internal.SFN_GetListToTable(NULL)
   
   SELECT @Count = COUNT(*) FROM @ListItems 
   EXEC TST.Assert.Equals 'The list should have no items', 0, @Count 
   
END
GO

CREATE PROCEDURE dbo.SQLTest_GetListToTable#NoItems
AS 
BEGIN

   DECLARE @Count int
   DECLARE @ListItems TABLE (ListItem varchar(500) PRIMARY KEY NOT NULL)
   
   INSERT INTO @ListItems SELECT * FROM TST.Internal.SFN_GetListToTable('')
   
   SELECT @Count = COUNT(*) FROM @ListItems 
   EXEC TST.Assert.Equals 'The list should have no items', 0, @Count 
   
END
GO


CREATE PROCEDURE dbo.SQLTest_GetListToTable#OneItem
AS 
BEGIN

   DECLARE @Count int
   DECLARE @ListItems TABLE (ListItem varchar(500) PRIMARY KEY NOT NULL)
   
   DELETE FROM @ListItems 
   INSERT INTO @ListItems SELECT * FROM TST.Internal.SFN_GetListToTable('  ')
   
   SELECT @Count = COUNT(*) FROM @ListItems 
   EXEC TST.Assert.Equals 'The list should have one item', 1, @Count 
   
   SELECT @Count = COUNT(*) FROM @ListItems WHERE ListItem = '  '
   EXEC TST.Assert.Equals 'The list should contain ''  ''', 1, @Count 

   DELETE FROM @ListItems 
   INSERT INTO @ListItems SELECT * FROM TST.Internal.SFN_GetListToTable('ListItem')
   
   SELECT @Count = COUNT(*) FROM @ListItems 
   EXEC TST.Assert.Equals 'The list should have one item', 1, @Count 
   
   SELECT @Count = COUNT(*) FROM @ListItems WHERE ListItem = 'ListItem'
   EXEC TST.Assert.Equals 'The list should contain ''ListItem''', 1, @Count 

   DELETE FROM @ListItems 
   INSERT INTO @ListItems SELECT * FROM TST.Internal.SFN_GetListToTable(' ListItem ')
   
   SELECT @Count = COUNT(*) FROM @ListItems 
   EXEC TST.Assert.Equals 'The list should have one item', 1, @Count 
   
   SELECT @Count = COUNT(*) FROM @ListItems WHERE ListItem = ' ListItem '
   EXEC TST.Assert.Equals 'The list should contain '' ListItem ''', 1, @Count 

END
GO

CREATE PROCEDURE dbo.SQLTest_GetListToTable#ThreeItems
AS 
BEGIN

   DECLARE @Count int
   DECLARE @ListItems TABLE (ListItem varchar(500) PRIMARY KEY NOT NULL)
   
   INSERT INTO @ListItems SELECT * FROM TST.Internal.SFN_GetListToTable('ListItem1;ListItem2;ListItem3')
   
   SELECT @Count = COUNT(*) FROM @ListItems 
   EXEC TST.Assert.Equals 'The list should have 3 items ', 3, @Count 
   
   SELECT @Count = COUNT(*) FROM @ListItems WHERE ListItem = 'ListItem1'
   EXEC TST.Assert.Equals 'The list should contain ListItem1', 1, @Count 

   SELECT @Count = COUNT(*) FROM @ListItems WHERE ListItem = 'ListItem2'
   EXEC TST.Assert.Equals 'The list should contain ListItem2', 1, @Count 

   SELECT @Count = COUNT(*) FROM @ListItems WHERE ListItem = 'ListItem2'
   EXEC TST.Assert.Equals 'The list should contain ListItem2', 1, @Count 

END
GO


CREATE PROCEDURE dbo.SQLTest_GetListToTable#VariousSpacing
AS 
BEGIN

   DECLARE @Count int
   DECLARE @ListItems TABLE (ListItem varchar(500) PRIMARY KEY NOT NULL)
   
   INSERT INTO @ListItems SELECT * FROM TST.Internal.SFN_GetListToTable(';;  ;A B C; A B C ;;;')
   
   SELECT @Count = COUNT(*) FROM @ListItems 
   EXEC TST.Assert.Equals 'The list should have 3 items ', 3, @Count 
   
   SELECT @Count = COUNT(*) FROM @ListItems WHERE ListItem = '  '
   EXEC TST.Assert.Equals 'The list should contain ''  ''', 1, @Count 

   SELECT @Count = COUNT(*) FROM @ListItems WHERE ListItem = 'A B C'
   EXEC TST.Assert.Equals 'The list should contain ''A B C''', 1, @Count 

   SELECT @Count = COUNT(*) FROM @ListItems WHERE ListItem = ' A B C '
   EXEC TST.Assert.Equals 'The list should contain '' A B C ''', 1, @Count 

END
GO

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- END test stored procedures
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- START BASIC features. API testing
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- =======================================================================
-- In depth test of Log
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#Log
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'            ,
      @TestName            = 'SQLTest_Log'         ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateNoSystemErrors                          @TestSessionId=@TestSessionId
   EXEC dbo.ValidateTestButNoSuiteSetupTeardownRecorded     @TestSessionId=@TestSessionId, @SProcName='SQLTest_Log'

   -- Make sure that all the messages from all tests were recorded and not lost due to rolling back of a transaction
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Log', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='Test log message in SQLTest_Log ĂÎÂȘȚăîâșț'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Log', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='Test pass message in SQLTest_Log ĂÎÂȘȚăîâșț'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Log', @ExpectedLogEntryCount=2

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of Log when the context message is NULL.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#LogNullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'            ,
      @TestName            = 'SQLTest_LogNullContext',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateNoSystemErrors                          @TestSessionId=@TestSessionId
   EXEC dbo.ValidateTestButNoSuiteSetupTeardownRecorded     @TestSessionId=@TestSessionId, @SProcName='SQLTest_LogNullContext'

   -- Make sure that all the messages from all tests were recorded and not lost due to rolling back of a transaction
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_LogNullContext', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage=''
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_LogNullContext', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='Test pass message in SQLTest_LogNullContext'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_LogNullContext', @ExpectedLogEntryCount=2

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO


-- =======================================================================
-- In depth test of Fail
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#Fail
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'            ,
      @TestName            = 'SQLTest_Fail'        ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_Fail', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessage='Test fail message in SQLTest_Fail ĂÎÂȘȚăîâșț'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- =======================================================================
-- In depth test of Fail when the context message is NULL.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#FailNullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'            ,
      @TestName            = 'SQLTest_FailNullContext',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_FailNullContext', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessage=''

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Tests the behavior of Pass by calling it directly.
-- Note that we have more in depth validation for Pass.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#DirectCall_Pass
AS
BEGIN
   EXEC TST.Assert.Pass 'Test TST.Assert.Pass'
END
GO

-- =======================================================================
-- In depth test of Pass
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#Pass
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'  ,
      @TestName            = 'SQLTest_Pass'        ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_Pass', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Test pass message in SQLTest_Pass'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of Pass when the context message is NULL.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#PassNullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'  ,
      @TestName            = 'SQLTest_PassNullContext',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_PassNullContext', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage=''

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Tests the behavior of passing Assert.Equals by calling it directly.
-- Note that we have more in depth validation for Assert.Equals.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#DirectCall_AssertEqualsTrueByDataType
AS
BEGIN

   DECLARE @Var_bigint              bigint     
   DECLARE @Var_numeric             numeric(38,15)    
   DECLARE @Var_bit                 bit        
   DECLARE @Var_smallint            smallint   
   DECLARE @Var_decimal             decimal(38,15)    
   DECLARE @Var_smallmoney          smallmoney 
   DECLARE @Var_int                 int        
   DECLARE @Var_tinyint             tinyint    
   DECLARE @Var_money               money      
   DECLARE @Var_datetime            datetime   
   DECLARE @Var_char                char       
   DECLARE @Var_varchar             varchar(20)
   DECLARE @Var_nchar               nchar      
   DECLARE @Var_nvarchar            nvarchar(20)   
   DECLARE @Var_binary              binary(10)     
   DECLARE @Var_sql_variant         sql_variant

   SET @Var_bigint                  = CAST(9223372036854775807 AS bigint             )
   SET @Var_numeric                 = CAST(12345678901234567890123.456789012345678 AS numeric(38,15)   )
   SET @Var_bit                     = CAST(1 AS bit                                  )
   SET @Var_smallint                = CAST(32767 AS smallint                         )
   SET @Var_decimal                 = CAST(12345678901234567890123.456789012345678 AS decimal(38,15)   )
   SET @Var_smallmoney              = CAST(-214748.3648  AS smallmoney               )
   SET @Var_int                     = CAST(-2147483648 AS int                        )
   SET @Var_tinyint                 = CAST(255 AS tinyint                            )
   SET @Var_money                   = CAST(922337203685477.5807 AS money             )
   SET @Var_datetime                = CAST('2001-01-01 23:59:59.199' AS datetime     )
   SET @Var_char                    = 'a'
   SET @Var_varchar                 = '12345678901234567890'
   SET @Var_nchar                   = N'Ă'
   SET @Var_nvarchar                = N'ĂÎÂȘȚ abc ăîâșț'
   SET @Var_binary                  = CAST('1111' AS binary                          )
   SET @Var_sql_variant             = CAST(1 AS sql_variant                          )

   EXEC TST.Assert.Equals 'Test Assert bigint'       , @Var_bigint       , @Var_bigint      
   EXEC TST.Assert.Equals 'Test Assert numeric'      , @Var_numeric      , @Var_numeric     
   EXEC TST.Assert.Equals 'Test Assert bit'          , @Var_bit          , @Var_bit         
   EXEC TST.Assert.Equals 'Test Assert smallint'     , @Var_smallint     , @Var_smallint    
   EXEC TST.Assert.Equals 'Test Assert decimal'      , @Var_decimal      , @Var_decimal     
   EXEC TST.Assert.Equals 'Test Assert smallmoney'   , @Var_smallmoney   , @Var_smallmoney  
   EXEC TST.Assert.Equals 'Test Assert int'          , @Var_int          , @Var_int         
   EXEC TST.Assert.Equals 'Test Assert tinyint'      , @Var_tinyint      , @Var_tinyint     
   EXEC TST.Assert.Equals 'Test Assert money'        , @Var_money        , @Var_money       
   EXEC TST.Assert.Equals 'Test Assert datetime'     , @Var_datetime     , @Var_datetime    
   EXEC TST.Assert.Equals 'Test Assert char'         , @Var_char         , @Var_char        
   EXEC TST.Assert.Equals 'Test Assert varchar'      , @Var_varchar      , @Var_varchar     
   EXEC TST.Assert.Equals 'Test Assert nchar'        , @Var_nchar        , @Var_nchar       
   EXEC TST.Assert.Equals 'Test Assert nvarchar'     , @Var_nvarchar     , @Var_nvarchar    
   EXEC TST.Assert.Equals 'Test Assert binary'       , @Var_binary       , @Var_binary      
   EXEC TST.Assert.Equals 'Test Assert sql_variant'  , @Var_sql_variant  , @Var_sql_variant 

END
GO

-- =======================================================================
-- Tests the behavior of Assert.Equals the expected value is passed 
-- using a literal value
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#DirectCall_AssertEqualsAgainstLiteralValues
AS
BEGIN

   DECLARE @Var_bigint              bigint     
   DECLARE @Var_numeric1            numeric(38,15)   
   DECLARE @Var_numeric2            numeric(6,3)   
   DECLARE @Var_bit0                bit        
   DECLARE @Var_bit1                bit        
   DECLARE @Var_smallint            smallint   
   DECLARE @Var_decimal             decimal(38,15)
   DECLARE @Var_smallmoney1         smallmoney 
   DECLARE @Var_smallmoney2         smallmoney 
   DECLARE @Var_smallmoney3         smallmoney 
   DECLARE @Var_int                 int        
   DECLARE @Var_tinyint             tinyint    
   DECLARE @Var_money1              money      
   DECLARE @Var_money2              money      
   DECLARE @Var_money3              money      
   DECLARE @Var_datetime            datetime   
   DECLARE @Var_char                char       
   DECLARE @Var_varchar             varchar(20)
   DECLARE @Var_nchar               nchar      
   DECLARE @Var_nvarchar            nvarchar(20)   
   DECLARE @Var_binary              binary(10)     
   DECLARE @Var_uniqueidentifier    uniqueidentifier
   DECLARE @Var_sql_variant         sql_variant

   SET @Var_bigint                  = CAST(9223372036854775807 AS bigint             )
   SET @Var_numeric1                = CAST(12345678901234567890123.456789012345678 AS numeric(38,15)   )
   SET @Var_numeric2                = CAST(123.456 AS numeric(6,3)                   )
   SET @Var_bit0                    = CAST(0 AS bit                                  )
   SET @Var_bit1                    = CAST(1 AS bit                                  )
   SET @Var_smallint                = CAST(32767 AS smallint                         )
   SET @Var_decimal                 = CAST(12345678901234567890123.456789012345678 AS decimal(38,15)   )
   SET @Var_smallmoney1             = CAST( 214748.3647 AS smallmoney                )
   SET @Var_smallmoney2             = CAST(-214748.3648  AS smallmoney               )
   SET @Var_smallmoney3             = CAST(1234.5678  AS smallmoney                  )
   SET @Var_int                     = CAST(-2147483648 AS int                        )
   SET @Var_tinyint                 = CAST(255 AS tinyint                            )
   SET @Var_money1                  = CAST( 922337203685477.5807 AS money            )
   SET @Var_money2                  = CAST(-922337203685477.5808 AS money            )
   SET @Var_money3                  = CAST(1234.5678 AS money                        )
   SET @Var_datetime                = CAST('2001-01-01 23:59:59.199' AS datetime     )
   SET @Var_char                    = 'A'
   SET @Var_varchar                 = '12345678901234567890'
   SET @Var_nchar                   = N'Ă'
   SET @Var_nvarchar                = N'ĂÎÂȘȚ abc ăîâșț'
   SET @Var_binary                  = CAST('1111' AS binary(10)                      )
   SET @Var_uniqueidentifier        = 'CAC8EF33-D483-4f1f-9D64-B8EB3965D5A6'
   SET @Var_sql_variant             = CAST(1 AS sql_variant                          )

   EXEC TST.Assert.Equals 'Test Assert bigint'          , 9223372036854775807                         , @Var_bigint      
   EXEC TST.Assert.Equals 'Test Assert numeric'         , 12345678901234567890123.456789012345678     , @Var_numeric1     
   EXEC TST.Assert.Equals 'Test Assert numeric'         , 123.456                                     , @Var_numeric2     
   EXEC TST.Assert.Equals 'Test Assert bit 0'           , 0                                           , @Var_bit0        
   EXEC TST.Assert.Equals 'Test Assert bit 1'           , 1                                           , @Var_bit1        
   EXEC TST.Assert.Equals 'Test Assert smallint'        , 32767                                       , @Var_smallint    
   EXEC TST.Assert.Equals 'Test Assert decimal'         , 12345678901234567890123.456789012345678     , @Var_decimal     
   EXEC TST.Assert.Equals 'Test Assert smallmoney 1'    ,  214748.3647                                , @Var_smallmoney1  
   EXEC TST.Assert.Equals 'Test Assert smallmoney 2'    , -214748.3648                                , @Var_smallmoney2  
   EXEC TST.Assert.Equals 'Test Assert smallmoney 3'    ,    1234.5678                                , @Var_smallmoney3
   EXEC TST.Assert.Equals 'Test Assert int'             , -2147483648                                 , @Var_int         
   EXEC TST.Assert.Equals 'Test Assert tinyint'         , 255                                         , @Var_tinyint     
   EXEC TST.Assert.Equals 'Test Assert money 1'         ,  922337203685477.5807                       , @Var_money1       
   EXEC TST.Assert.Equals 'Test Assert money 2'         , -922337203685477.5808                       , @Var_money2       
   EXEC TST.Assert.Equals 'Test Assert money 3'         , 1234.5678                                   , @Var_money3       
   EXEC TST.Assert.Equals 'Test Assert datetime'        , @Var_datetime                               , @Var_datetime    
   EXEC TST.Assert.Equals 'Test Assert char'            , 'A'                                         , @Var_char        
   EXEC TST.Assert.Equals 'Test Assert varchar'         , '12345678901234567890'                      , @Var_varchar     
   EXEC TST.Assert.Equals 'Test Assert nchar'           , N'Ă'                                        , @Var_nchar       
   EXEC TST.Assert.Equals 'Test Assert nvarchar'        , N'ĂÎÂȘȚ abc ăîâșț'                              , @Var_nvarchar    
   EXEC TST.Assert.Equals 'Test Assert binary'          , 0x31313131000000000000                      , @Var_binary      
   EXEC TST.Assert.Equals 'Test Assert uniqueidentifier', @Var_uniqueidentifier                       , @Var_uniqueidentifier 
   EXEC TST.Assert.Equals 'Test Assert sql_variant'     , 1                                           , @Var_sql_variant 

END
GO

-- =======================================================================
-- In depth test of passing Assert.Equals
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertEqualsTrue
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertEqualsTrue'  ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertEqualsTrue', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='%Test Assert.Equals in SQLTest_AssertEqualsTrue ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.Equals
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertEqualsFalse
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertEqualsFalse' ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertEqualsFalse', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.Equals in SQLTest_AssertEqualsFalse ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.Equals when NULL is used for 
-- the @ExpectedValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertEqualsExpectedParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                       ,
      @TestName            = 'SQLTest_AssertEqualsExpectedParamIsNull'  ,
      @ResultsFormat       = 'None'                                     ,
      @CleanTemporaryData  = 0                                          ,
      @TestSessionId       = @TestSessionId OUT                         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertEqualsExpectedParamIsNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='Invalid call to Assert.Equals. %Test Assert.Equals in SQLTest_AssertEqualsExpectedParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.Equals when NULL is used for 
-- the @ActualValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertEqualsActualParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertEqualsActualParamIsNull' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertEqualsActualParamIsNull', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.Equals in SQLTest_AssertEqualsActualParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.Equals when NULL is used for 
-- both @ExpectedValue and @ActualValue parameters.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertEqualsBothParamsAreNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertEqualsBothParamsAreNull' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertEqualsBothParamsAreNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='%Test Assert.Equals in SQLTest_AssertEqualsBothParamsAreNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of passing Assert.Equals when ContextMessage is NULL.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertEqualsNullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertEqualsNullContext' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertEqualsNullContext', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='Assert.Equals passed. ^[^]%',
         @EscapeCharacter='^'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.Equals for each datatype. 
-- Note that we are running an entire suite implemented in TSTCheck
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertEqualsFalseByDataType
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @SProcNames           varchar(1000)
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheck'        ,
      @SuiteName           = 'AssertEqualsFail'          ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors              @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists          @TestSessionId=@TestSessionId, @SuiteName='AssertEqualsFail'
   
   SET @SProcNames = 
            'SQLTest_AssertEqualsFail#bigint,' + 
            'SQLTest_AssertEqualsFail#numeric,' + 
            'SQLTest_AssertEqualsFail#bit,' + 
            'SQLTest_AssertEqualsFail#smallint,' + 
            'SQLTest_AssertEqualsFail#decimal,' + 
            'SQLTest_AssertEqualsFail#smallmoney,' + 
            'SQLTest_AssertEqualsFail#int,' + 
            'SQLTest_AssertEqualsFail#tinyint,' + 
            'SQLTest_AssertEqualsFail#money,' + 
            'SQLTest_AssertEqualsFail#datetime,' + 
            'SQLTest_AssertEqualsFail#char,' + 
            'SQLTest_AssertEqualsFail#varchar,' + 
            'SQLTest_AssertEqualsFail#nchar,' + 
            'SQLTest_AssertEqualsFail#nvarchar,' + 
            'SQLTest_AssertEqualsFail#binary,' + 
            'SQLTest_AssertEqualsFail#sql_variant,'

   EXEC dbo.ValidateOnlyGivenTestExists               @TestSessionId=@TestSessionId, @SProcsNames=@SProcNames, @SProcType='Test'
   
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#bigint'       , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#numeric'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#bit'          , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#smallint'     , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#decimal'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#smallmoney'   , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#int'          , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#tinyint'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#money'        , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#datetime'     , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#char'         , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#varchar'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#nchar'        , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#nvarchar'     , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#binary'       , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsFail#sql_variant'  , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.Equals in suite AssertEqualsFail%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.Equals when called with incompatible 
-- data types
-- Note that we are running an entire suite implemented in TSTCheck
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertEqualsIncompatibleDataTypeByDataType
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @SProcNames           varchar(1000)
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheck'        ,
      @SuiteName           = 'AssertEqualsIncompatibleData'          ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors              @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists          @TestSessionId=@TestSessionId, @SuiteName='AssertEqualsIncompatibleData'
   
   SET @SProcNames = 
            'SQLTest_AssertEqualsIncompatibleData#bigint_float,' + 
            'SQLTest_AssertEqualsIncompatibleData#numeric_real,' + 
            'SQLTest_AssertEqualsIncompatibleData#bit_datetime,' + 
            'SQLTest_AssertEqualsIncompatibleData#varchar_smallint,' + 
            'SQLTest_AssertEqualsIncompatibleData#varchar_binary,' + 
            'SQLTest_AssertEqualsIncompatibleData#varchar_uniqueidentifier,'

   EXEC dbo.ValidateOnlyGivenTestExists               @TestSessionId=@TestSessionId, @SProcsNames=@SProcNames, @SProcType='Test'
   
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsIncompatibleData#bigint_float'              , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.Equals. [Test Assert in SQLTest_AssertEqualsIncompatibleData#bigint_float] @ExpectedValue (bigint) and @ActualValue (float) have incompatible types. Consider an explicit CONVERT, calling Assert.NumericEquals or calling Assert.FloatEquals'
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsIncompatibleData#numeric_real'              , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.Equals. [Test Assert in SQLTest_AssertEqualsIncompatibleData#numeric_real] @ExpectedValue (numeric) and @ActualValue (real) have incompatible types. Consider an explicit CONVERT, calling Assert.NumericEquals or calling Assert.FloatEquals'
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsIncompatibleData#bit_datetime'              , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.Equals. [Test Assert in SQLTest_AssertEqualsIncompatibleData#bit_datetime] @ExpectedValue (bit) and @ActualValue (datetime) have incompatible types. Consider an explicit CONVERT, calling Assert.NumericEquals or calling Assert.FloatEquals'
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsIncompatibleData#varchar_smallint'          , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.Equals. [Test Assert in SQLTest_AssertEqualsIncompatibleData#varchar_smallint] @ExpectedValue (varchar) and @ActualValue (smallint) have incompatible types. Consider an explicit CONVERT, calling Assert.NumericEquals or calling Assert.FloatEquals'
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsIncompatibleData#varchar_binary'            , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.Equals. [Test Assert in SQLTest_AssertEqualsIncompatibleData#varchar_binary] @ExpectedValue (varchar) and @ActualValue (binary) have incompatible types. Consider an explicit CONVERT, calling Assert.NumericEquals or calling Assert.FloatEquals'
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsIncompatibleData#varchar_uniqueidentifier'  , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.Equals. [Test Assert in SQLTest_AssertEqualsIncompatibleData#varchar_uniqueidentifier] @ExpectedValue (varchar) and @ActualValue (uniqueidentifier) have incompatible types. Consider an explicit CONVERT, calling Assert.NumericEquals or calling Assert.FloatEquals'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.Equals when called with parameters 
-- of approximate numeric types (float or real)
-- Note that we are running an entire suite implemented in TSTCheck
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertEqualsApproximateNumeric
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @SProcNames           varchar(1000)
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheck'        ,
      @SuiteName           = 'AssertEqualsApproximateNumeric'          ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors              @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists          @TestSessionId=@TestSessionId, @SuiteName='AssertEqualsApproximateNumeric'
   
   SET @SProcNames = 
            'SQLTest_AssertEqualsApproximateNumeric#float,' + 
            'SQLTest_AssertEqualsApproximateNumeric#real,'

   EXEC dbo.ValidateOnlyGivenTestExists               @TestSessionId=@TestSessionId, @SProcsNames=@SProcNames, @SProcType='Test'
   
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsApproximateNumeric#float' , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.Equals. [Test Assert in SQLTest_AssertEqualsApproximateNumeric#_float] Float or real cannot be used when calling Assert.Equals since this could produce unreliable results. Use Assert.FloatEquals.'
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertEqualsApproximateNumeric#real'  , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.Equals. [Test Assert in SQLTest_AssertEqualsApproximateNumeric#_real] Float or real cannot be used when calling Assert.Equals since this could produce unreliable results. Use Assert.FloatEquals.'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Tests the behavior of passing Assert.NotEquals by calling it directly.
-- Note that we have more in depth validation for Assert.NotEquals.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#DirectCall_AssertNotEqualsTrueByDataType
AS
BEGIN

   DECLARE @Var_bigint_1           bigint           ; DECLARE @Var_bigint_2           bigint     
   DECLARE @Var_numeric_1          numeric(38,15)   ; DECLARE @Var_numeric_2          numeric(38,15)
   DECLARE @Var_bit_1              bit              ; DECLARE @Var_bit_2              bit        
   DECLARE @Var_smallint_1         smallint         ; DECLARE @Var_smallint_2         smallint   
   DECLARE @Var_decimal_1          decimal(38,15)   ; DECLARE @Var_decimal_2          decimal(38,15)
   DECLARE @Var_smallmoney_1       smallmoney       ; DECLARE @Var_smallmoney_2       smallmoney 
   DECLARE @Var_int_1              int              ; DECLARE @Var_int_2              int        
   DECLARE @Var_tinyint_1          tinyint          ; DECLARE @Var_tinyint_2          tinyint    
   DECLARE @Var_money_1            money            ; DECLARE @Var_money_2            money      
   DECLARE @Var_datetime_1         datetime         ; DECLARE @Var_datetime_2         datetime   
   DECLARE @Var_char_1             char             ; DECLARE @Var_char_2             char       
   DECLARE @Var_varchar_1          varchar(20)      ; DECLARE @Var_varchar_2          varchar(20)
   DECLARE @Var_nchar_1            nchar            ; DECLARE @Var_nchar_2            nchar      
   DECLARE @Var_nvarchar_1         nvarchar(20)     ; DECLARE @Var_nvarchar_2         nvarchar(20)
   DECLARE @Var_binary_1           binary(10)       ; DECLARE @Var_binary_2           binary(10)
   DECLARE @Var_uniqueidentifier1   uniqueidentifier; DECLARE @Var_uniqueidentifier2   uniqueidentifier
   DECLARE @Var_sql_variant_1      sql_variant      ; DECLARE @Var_sql_variant_2      sql_variant

   SET @Var_bigint_1          = CAST(9223372036854775807 AS bigint             ) ; SET @Var_bigint_2           = CAST(9223372036854775806 AS bigint            )
   SET @Var_numeric_1         = CAST(12345678901234567890123.456789012345678 AS numeric(38,15)   ) ; SET @Var_numeric_2       = CAST(12345678901234567890123.456789012345679 AS numeric(38,15)  )
   SET @Var_bit_1             = CAST(1 AS bit                                  ) ; SET @Var_bit_2              = CAST(0 AS bit                                 )
   SET @Var_smallint_1        = CAST(32767 AS smallint                         ) ; SET @Var_smallint_2         = CAST(32766 AS smallint                        )
   SET @Var_decimal_1         = CAST(12345678901234567890123.456789012345678 AS decimal(38,15)   ) ; SET @Var_decimal_2       = CAST(12345678901234567890123.456789012345679 AS decimal(38,15)  )
   SET @Var_smallmoney_1      = CAST(-214748.3648  AS smallmoney               ) ; SET @Var_smallmoney_2       = CAST(-214748.3647  AS smallmoney              )
   SET @Var_int_1             = CAST(-2147483648 AS int                        ) ; SET @Var_int_2              = CAST(-2147483647 AS int                       )
   SET @Var_tinyint_1         = CAST(255 AS tinyint                            ) ; SET @Var_tinyint_2          = CAST(254 AS tinyint                           )
   SET @Var_money_1           = CAST(922337203685477.5807 AS money             ) ; SET @Var_money_2            = CAST(922337203685477.5806 AS money            )
   SET @Var_datetime_1        = CAST('2001-01-01 23:59:59.199' AS datetime     ) ; SET @Var_datetime_2         = CAST('2001-01-01 23:59:59.198' AS datetime    )
   SET @Var_char_1            = CAST('a' AS char                               ) ; SET @Var_char_2             = CAST('B' AS char                              )
   SET @Var_varchar_1         = '12345678901234567890'                           ; SET @Var_varchar_2          = '12345678901234567891'
   SET @Var_nchar_1           = N'ă'                                             ; SET @Var_nchar_2            = 'a'
   SET @Var_nvarchar_1        = N'ĂÎÂȘȚ abc ăîâșț'                               ; SET @Var_nvarchar_2         = N'ĂÎÂȘȚ abc ăîâșt'
   SET @Var_binary_1          = CAST('1111' AS binary(10)                      ) ; SET @Var_binary_2           = CAST('11111' AS binary(10)                    )
   SET @Var_uniqueidentifier1 = 'CAC8EF33-D483-4f1f-9D64-B8EB3965D5A6'           ; SET @Var_uniqueidentifier2  = 'CAC8EF33-D483-4f1f-9D64-B8EB3965D500'
   SET @Var_sql_variant_1     = CAST(1 AS sql_variant                          ) ; SET @Var_sql_variant_2      = CAST(2 AS sql_variant                         )

   EXEC TST.Assert.NotEquals 'Test Assert bigint'       , @Var_bigint_1          , @Var_bigint_2        
   EXEC TST.Assert.NotEquals 'Test Assert numeric'      , @Var_numeric_1         , @Var_numeric_2       
   EXEC TST.Assert.NotEquals 'Test Assert bit'          , @Var_bit_1             , @Var_bit_2           
   EXEC TST.Assert.NotEquals 'Test Assert smallint'     , @Var_smallint_1        , @Var_smallint_2      
   EXEC TST.Assert.NotEquals 'Test Assert decimal'      , @Var_decimal_1         , @Var_decimal_2       
   EXEC TST.Assert.NotEquals 'Test Assert smallmoney'   , @Var_smallmoney_1      , @Var_smallmoney_2    
   EXEC TST.Assert.NotEquals 'Test Assert int'          , @Var_int_1             , @Var_int_2           
   EXEC TST.Assert.NotEquals 'Test Assert tinyint'      , @Var_tinyint_1         , @Var_tinyint_2       
   EXEC TST.Assert.NotEquals 'Test Assert money'        , @Var_money_1           , @Var_money_2         
   EXEC TST.Assert.NotEquals 'Test Assert datetime'     , @Var_datetime_1        , @Var_datetime_2      
   EXEC TST.Assert.NotEquals 'Test Assert char'         , @Var_char_1            , @Var_char_2          
   EXEC TST.Assert.NotEquals 'Test Assert varchar'      , @Var_varchar_1         , @Var_varchar_2       
   EXEC TST.Assert.NotEquals 'Test Assert nchar'        , @Var_nchar_1           , @Var_nchar_2         
   EXEC TST.Assert.NotEquals 'Test Assert nvarchar'     , @Var_nvarchar_1        , @Var_nvarchar_2      
   EXEC TST.Assert.NotEquals 'Test Assert binary'       , @Var_binary_1          , @Var_binary_2        
   EXEC TST.Assert.NotEquals 'Test Assert binary'       , @Var_uniqueidentifier1 , @Var_uniqueidentifier2
   EXEC TST.Assert.NotEquals 'Test Assert sql_variant'  , @Var_sql_variant_1     , @Var_sql_variant_2   

END
GO

-- =======================================================================
-- In depth test of passing Assert.NotEquals
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotEqualsTrue
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'           ,
      @TestName            = 'SQLTest_AssertNotEqualsTrue'  ,
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNotEqualsTrue', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='%Test Assert.NotEquals in SQLTest_AssertNotEqualsTrue ĂÎÂȘȚăîâșț%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.NotEquals
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotEqualsFalse
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'           ,
      @TestName            = 'SQLTest_AssertNotEqualsFalse' ,
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNotEqualsFalse', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.NotEquals in SQLTest_AssertNotEqualsFalse ĂÎÂȘȚăîâșț%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- =======================================================================
-- In depth test of failing Assert.NotEquals when NULL is used for 
-- the @ExpectedNotValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotEqualsExpectedParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                          ,
      @TestName            = 'SQLTest_AssertNotEqualsExpectedParamIsNull'  ,
      @ResultsFormat       = 'None'                                        ,
      @CleanTemporaryData  = 0                                             ,
      @TestSessionId       = @TestSessionId OUT                            ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNotEqualsExpectedParamIsNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='Invalid call to Assert.NotEquals. %Test Assert.NotEquals in SQLTest_AssertNotEqualsExpectedParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.NotEquals when NULL is used for 
-- the @ActualValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotEqualsActualParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                       ,
      @TestName            = 'SQLTest_AssertNotEqualsActualParamIsNull' ,
      @ResultsFormat       = 'None'                                     ,
      @CleanTemporaryData  = 0                                          ,
      @TestSessionId       = @TestSessionId OUT                         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNotEqualsActualParamIsNull', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.NotEquals in SQLTest_AssertNotEqualsActualParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.NotEquals when NULL is used for 
-- both @ExpectedNotValue and @ActualValue parameters.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotEqualsBothParamsAreNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                       ,
      @TestName            = 'SQLTest_AssertNotEqualsBothParamsAreNull' ,
      @ResultsFormat       = 'None'                                     ,
      @CleanTemporaryData  = 0                                          ,
      @TestSessionId       = @TestSessionId OUT                         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNotEqualsBothParamsAreNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='%Test Assert.NotEquals in SQLTest_AssertNotEqualsBothParamsAreNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of passing Assert.NotEquals when ContextMessage is NULL.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotEqualsNullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                       ,
      @TestName            = 'SQLTest_AssertNotEqualsNullContext' ,
      @ResultsFormat       = 'None'                                     ,
      @CleanTemporaryData  = 0                                          ,
      @TestSessionId       = @TestSessionId OUT                         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNotEqualsNullContext', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='Assert.NotEquals passed. ^[^]%',
         @EscapeCharacter= '^'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.NotEquals for each datatype. 
-- Note that we are running an entire suite implemented in TSTCheck
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotEqualsFalseByDataType
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @SProcNames           varchar(1000)
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheck'        ,
      @SuiteName           = 'AssertNotEqualsFail'       ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors              @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists          @TestSessionId=@TestSessionId, @SuiteName='AssertNotEqualsFail'
   
   SET @SProcNames = 
            'SQLTest_AssertNotEqualsFail#bigint,' + 
            'SQLTest_AssertNotEqualsFail#numeric,' + 
            'SQLTest_AssertNotEqualsFail#bit,' + 
            'SQLTest_AssertNotEqualsFail#smallint,' + 
            'SQLTest_AssertNotEqualsFail#decimal,' + 
            'SQLTest_AssertNotEqualsFail#smallmoney,' + 
            'SQLTest_AssertNotEqualsFail#int,' + 
            'SQLTest_AssertNotEqualsFail#tinyint,' + 
            'SQLTest_AssertNotEqualsFail#money,' + 
            'SQLTest_AssertNotEqualsFail#datetime,' + 
            'SQLTest_AssertNotEqualsFail#char,' + 
            'SQLTest_AssertNotEqualsFail#varchar,' + 
            'SQLTest_AssertNotEqualsFail#nchar,' + 
            'SQLTest_AssertNotEqualsFail#nvarchar,' + 
            'SQLTest_AssertNotEqualsFail#binary,' + 
            'SQLTest_AssertNotEqualsFail#sql_variant,'

   EXEC dbo.ValidateOnlyGivenTestExists               @TestSessionId=@TestSessionId, @SProcsNames=@SProcNames, @SProcType='Test'
   
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#bigint'       , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#numeric'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#bit'          , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#smallint'     , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#decimal'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#smallmoney'   , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#int'          , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#tinyint'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#money'        , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#datetime'     , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#char'         , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#varchar'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#nchar'        , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#nvarchar'     , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#binary'       , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsFail#sql_variant'  , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NotEquals in suite AssertNotEqualsFail%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.NotEquals when called with incompatible 
-- data types
-- Note that we are running an entire suite implemented in TSTCheck
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotEqualsIncompatibleDataTypeByDataType
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @SProcNames           varchar(1000)
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheck'        ,
      @SuiteName           = 'AssertNotEqualsIncompatibleData'          ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors              @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists          @TestSessionId=@TestSessionId, @SuiteName='AssertNotEqualsIncompatibleData'
   
   SET @SProcNames = 
            'SQLTest_AssertNotEqualsIncompatibleData#bigint_float,' + 
            'SQLTest_AssertNotEqualsIncompatibleData#numeric_real,' + 
            'SQLTest_AssertNotEqualsIncompatibleData#bit_datetime,' + 
            'SQLTest_AssertNotEqualsIncompatibleData#varchar_smallint,' + 
            'SQLTest_AssertNotEqualsIncompatibleData#varchar_binary,' + 
            'SQLTest_AssertNotEqualsIncompatibleData#varchar_uniqueidentifier,'

   EXEC dbo.ValidateOnlyGivenTestExists               @TestSessionId=@TestSessionId, @SProcsNames=@SProcNames, @SProcType='Test'
   
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsIncompatibleData#bigint_float'              , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.NotEquals. [Test Assert in SQLTest_AssertNotEqualsIncompatibleData#bigint_float] @ExpectedNotValue (bigint) and @ActualValue (float) have incompatible types. Consider an explicit CONVERT, calling Assert.NumericEquals or calling Assert.FloatEquals'
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsIncompatibleData#numeric_real'              , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.NotEquals. [Test Assert in SQLTest_AssertNotEqualsIncompatibleData#numeric_real] @ExpectedNotValue (numeric) and @ActualValue (real) have incompatible types. Consider an explicit CONVERT, calling Assert.NumericEquals or calling Assert.FloatEquals'
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsIncompatibleData#bit_datetime'              , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.NotEquals. [Test Assert in SQLTest_AssertNotEqualsIncompatibleData#bit_datetime] @ExpectedNotValue (bit) and @ActualValue (datetime) have incompatible types. Consider an explicit CONVERT, calling Assert.NumericEquals or calling Assert.FloatEquals'
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsIncompatibleData#varchar_smallint'          , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.NotEquals. [Test Assert in SQLTest_AssertNotEqualsIncompatibleData#varchar_smallint] @ExpectedNotValue (varchar) and @ActualValue (smallint) have incompatible types. Consider an explicit CONVERT, calling Assert.NumericEquals or calling Assert.FloatEquals'
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsIncompatibleData#varchar_binary'            , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.NotEquals. [Test Assert in SQLTest_AssertNotEqualsIncompatibleData#varchar_binary] @ExpectedNotValue (varchar) and @ActualValue (binary) have incompatible types. Consider an explicit CONVERT, calling Assert.NumericEquals or calling Assert.FloatEquals'
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsIncompatibleData#varchar_uniqueidentifier'  , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.NotEquals. [Test Assert in SQLTest_AssertNotEqualsIncompatibleData#varchar_uniqueidentifier] @ExpectedNotValue (varchar) and @ActualValue (uniqueidentifier) have incompatible types. Consider an explicit CONVERT, calling Assert.NumericEquals or calling Assert.FloatEquals'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.NotEquals when called with parameters 
-- of approximate numeric types (float or real)
-- Note that we are running an entire suite implemented in TSTCheck
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotEqualsApproximateNumeric
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @SProcNames           varchar(1000)
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheck'        ,
      @SuiteName           = 'AssertNotEqualsApproximateNumeric'          ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors              @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists          @TestSessionId=@TestSessionId, @SuiteName='AssertNotEqualsApproximateNumeric'
   
   SET @SProcNames = 
            'SQLTest_AssertNotEqualsApproximateNumeric#float,' + 
            'SQLTest_AssertNotEqualsApproximateNumeric#real,'

   EXEC dbo.ValidateOnlyGivenTestExists               @TestSessionId=@TestSessionId, @SProcsNames=@SProcNames, @SProcType='Test'
   
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsApproximateNumeric#float' , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.NotEquals. [Test Assert in SQLTest_AssertNotEqualsApproximateNumeric#_float] Float or real cannot be used when calling Assert.NotEquals since this could produce unreliable results. Use Assert.FloatNotEquals.'
   EXEC dbo.ValidateOnlyOneTestLogEntryExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNotEqualsApproximateNumeric#real'  , @ExpectedEntryType='E', @ExpectedLogMessage='Invalid call to Assert.NotEquals. [Test Assert in SQLTest_AssertNotEqualsApproximateNumeric#_real] Float or real cannot be used when calling Assert.NotEquals since this could produce unreliable results. Use Assert.FloatNotEquals.'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Tests the behavior of passing Assert.NumericEquals by calling it directly.
-- Note that we have more in depth validation for Assert.NumericEquals.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#DirectCall_AssertNumEqualsAgainstLiteralValues
AS
BEGIN

   DECLARE @Var_numeric             numeric(38,15)    
   DECLARE @Var_decimal             decimal(38,15)    
   DECLARE @Var_smallmoney1         smallmoney 
   DECLARE @Var_smallmoney2         smallmoney 
   DECLARE @Var_smallmoney3         smallmoney 
   DECLARE @Var_money1              money      
   DECLARE @Var_money2              money      
   DECLARE @Var_money3              money      
   DECLARE @Var_float               float      
   DECLARE @Var_real                real       
   DECLARE @Var_int                 int        

   SET @Var_numeric                 = CAST(12345678901234567890123.456789012345678 AS numeric(38,15)   )
   SET @Var_decimal                 = CAST(12345678901234567890123.456789012345678 AS decimal(38,15)   )
   SET @Var_smallmoney1             = CAST( 214748.3647 AS smallmoney                )
   SET @Var_smallmoney2             = CAST(-214748.3648  AS smallmoney               )
   SET @Var_smallmoney3             = CAST(1234.5678  AS smallmoney                  )
   SET @Var_money1                  = CAST( 922337203685477.5807 AS money            )
   SET @Var_money2                  = CAST(-922337203685477.5808 AS money            )
   SET @Var_money3                  = CAST(1234.5678 AS money                        )
   SET @Var_float                   = CAST(1.23456789012345 AS float                 )
   SET @Var_real                    = CAST(1.234567 AS real                          )
   SET @Var_int                     = CAST(100 AS int                                )

   EXEC TST.Assert.NumericEquals 'Test Assert numeric'      , 12345678901234567890123.456789012345678, @Var_numeric       , 0
   EXEC TST.Assert.NumericEquals 'Test Assert decimal'      , 12345678901234567890123.456789012345678, @Var_decimal       , 0
   EXEC TST.Assert.NumericEquals 'Test Assert smallmoney 1' ,  214748.3647              , @Var_smallmoney1   , 0
   EXEC TST.Assert.NumericEquals 'Test Assert smallmoney 2' , -214748.3648              , @Var_smallmoney2   , 0
   EXEC TST.Assert.NumericEquals 'Test Assert smallmoney 3' , 1234.5678                 , @Var_smallmoney3   , 0
   EXEC TST.Assert.NumericEquals 'Test Assert money 1'      , 922337203685477.5807      , @Var_money1        , 0
   EXEC TST.Assert.NumericEquals 'Test Assert money 2'      ,-922337203685477.5808      , @Var_money2        , 0
   EXEC TST.Assert.NumericEquals 'Test Assert money 3'      , 1234.5678                 , @Var_money3        , 0
   EXEC TST.Assert.NumericEquals 'Test Assert float'        , 1.23456789012345          , @Var_float         , 0
   EXEC TST.Assert.NumericEquals 'Test Assert real'         , 1.234567                  , @Var_real          , 0.0000001

   EXEC TST.Assert.NumericEquals 'Test Assert int'          , 100                       , @Var_int           , 0

END
GO


-- =======================================================================
-- Tests the behavior of passing Assert.NumericEquals by calling it directly.
-- Note that we have more in depth validation for Assert.NumericEquals.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#DirectCall_AssertNumEqualsToleranceAgainstLiteralValues
AS
BEGIN

   DECLARE @Var_numeric             numeric(38,15)    
   DECLARE @Var_decimal             decimal(38,15)    
   DECLARE @Var_smallmoney          smallmoney 
   DECLARE @Var_money               money      
   DECLARE @Var_float               float      
   DECLARE @Var_real                real       

   SET @Var_numeric                 = CAST(12345678901234567890123.456789012345678 AS numeric(38,15)   )
   SET @Var_decimal                 = CAST(12345678901234567890123.456789012345678 AS decimal(38,15)   )
   SET @Var_smallmoney              = CAST(1234.5678  AS smallmoney               )
   SET @Var_money                   = CAST(1234.5678 AS money             )
   SET @Var_float                   = CAST(1.23456789012345 AS float                 )
   SET @Var_real                    = CAST(1.234567 AS real                          )

   EXEC TST.Assert.NumericEquals 'Test Assert numeric'      , 12345678901234567890123.456789012345678, @Var_numeric       , 0.000000000000001
   EXEC TST.Assert.NumericEquals 'Test Assert decimal'      , 12345678901234567890123.456789012345678, @Var_decimal       , 0.000000000000001
   EXEC TST.Assert.NumericEquals 'Test Assert smallmoney'   , 1234.567         , @Var_smallmoney    , 0.001
   EXEC TST.Assert.NumericEquals 'Test Assert money'        , 1234.567         , @Var_money         , 0.001
   EXEC TST.Assert.NumericEquals 'Test Assert float'        , 1.234            , @Var_float         , 0.001
   EXEC TST.Assert.NumericEquals 'Test Assert real'         , 1.234            , @Var_real          , 0.001

END
GO

-- =======================================================================
-- In depth test of passing Assert.NumericEquals
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNumEqualsTrue
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertNumEqualsTrue',
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNumEqualsTrue', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='%Test Assert.NumericEquals in SQLTest_AssertNumEqualsTrue ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- =======================================================================
-- In depth test of failing Assert.NumericEquals
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNumEqualsFalse
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertNumEqualsFalse' ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNumEqualsFalse', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.NumericEquals in SQLTest_AssertNumEqualsFalse ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.NumericEquals when NULL is used for 
-- the @ExpectedValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNumEqualsExpectedParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                       ,
      @TestName            = 'SQLTest_AssertNumEqualsExpectedParamIsNull'  ,
      @ResultsFormat       = 'None'                                     ,
      @CleanTemporaryData  = 0                                          ,
      @TestSessionId       = @TestSessionId OUT                         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNumEqualsExpectedParamIsNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='Invalid call to Assert.NumericEquals. %Test Assert.NumericEquals in SQLTest_AssertNumEqualsExpectedParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- =======================================================================
-- In depth test of failing Assert.NumericEquals when NULL is used for 
-- the @ActualValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNumEqualsActualParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertNumEqualsActualParamIsNull' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNumEqualsActualParamIsNull', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.NumericEquals in SQLTest_AssertNumEqualsActualParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.NumericEquals when NULL is used for 
-- both @ExpectedValue and @ActualValue parameters.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNumEqualsBothParamsAreNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertNumEqualsBothParamsAreNull' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNumEqualsBothParamsAreNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='%Test Assert.NumericEquals in SQLTest_AssertNumEqualsBothParamsAreNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of passing Assert.NumericEquals when ContextMessage is NULL.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNumEqualsNullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertNumEqualsNullContext' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNumEqualsNullContext', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='Assert.NumericEquals passed. ^[^]%',
         @EscapeCharacter='^'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.NumericEquals for each datatype. 
-- Note that we are running an entire suite implemented in TSTCheck
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNumEqualsFalseByDataType
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @SProcNames           varchar(1000)
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheck'        ,
      @SuiteName           = 'AssertNumEqualsFail'          ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors              @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists          @TestSessionId=@TestSessionId, @SuiteName='AssertNumEqualsFail'
   
   SET @SProcNames = 
            'SQLTest_AssertNumEqualsFail#numeric,' + 
            'SQLTest_AssertNumEqualsFail#decimal,' + 
            'SQLTest_AssertNumEqualsFail#smallmoney,' + 
            'SQLTest_AssertNumEqualsFail#int,' + 
            'SQLTest_AssertNumEqualsFail#money,' + 
            'SQLTest_AssertNumEqualsFail#float,' + 
            'SQLTest_AssertNumEqualsFail#real'

   EXEC dbo.ValidateOnlyGivenTestExists               @TestSessionId=@TestSessionId, @SProcsNames=@SProcNames, @SProcType='Test'
   
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNumEqualsFail#numeric'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NumericEquals in suite AssertNumEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNumEqualsFail#decimal'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NumericEquals in suite AssertNumEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNumEqualsFail#smallmoney'   , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NumericEquals in suite AssertNumEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNumEqualsFail#int'          , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NumericEquals in suite AssertNumEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNumEqualsFail#money'        , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NumericEquals in suite AssertNumEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNumEqualsFail#float'        , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NumericEquals in suite AssertNumEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNumEqualsFail#real'         , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NumericEquals in suite AssertNumEqualsFail%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Tests the behavior of passing Assert.NumericNotEquals by calling it directly.
-- Note that we have more in depth validation for Assert.NumericNotEquals.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#DirectCall_AssertNumNotEqualsAgainstLiteralValues
AS
BEGIN

   DECLARE @Var_numeric             numeric(38,15)    
   DECLARE @Var_decimal             decimal(38,15)    
   DECLARE @Var_smallmoney1         smallmoney 
   DECLARE @Var_smallmoney2         smallmoney 
   DECLARE @Var_smallmoney3         smallmoney 
   DECLARE @Var_money1              money      
   DECLARE @Var_money2              money      
   DECLARE @Var_money3              money      
   DECLARE @Var_float               float      
   DECLARE @Var_real                real       
   DECLARE @Var_int                 int        

   SET @Var_numeric                 = CAST(12345678901234567890123.456789012345678 AS numeric(38,15)   )
   SET @Var_decimal                 = CAST(12345678901234567890123.456789012345678 AS decimal(38,15)   )
   SET @Var_smallmoney1             = CAST( 214748.3647 AS smallmoney                )
   SET @Var_smallmoney2             = CAST(-214748.3648  AS smallmoney               )
   SET @Var_smallmoney3             = CAST(1234.5678  AS smallmoney                  )
   SET @Var_money1                  = CAST( 922337203685477.5807 AS money            )
   SET @Var_money2                  = CAST(-922337203685477.5808 AS money            )
   SET @Var_money3                  = CAST(1234.5678 AS money                        )
   SET @Var_float                   = CAST(1.23456789012345 AS float                 )
   SET @Var_real                    = CAST(1.234567 AS real                          )
   SET @Var_int                     = CAST(100 AS int                                )

   EXEC TST.Assert.NumericNotEquals 'Test Assert numeric'      , 12345678901234567890123.456789012345676, @Var_numeric       , 0.000000000000001
   EXEC TST.Assert.NumericNotEquals 'Test Assert decimal'      , 12345678901234567890123.456789012345676, @Var_decimal       , 0.000000000000001
   EXEC TST.Assert.NumericNotEquals 'Test Assert smallmoney 1' ,  214748.3645              , @Var_smallmoney1   , 0.0001
   EXEC TST.Assert.NumericNotEquals 'Test Assert smallmoney 2' , -214748.3646              , @Var_smallmoney2   , 0.0001
   EXEC TST.Assert.NumericNotEquals 'Test Assert smallmoney 3' , 1234.5676                 , @Var_smallmoney3   , 0.0001
   EXEC TST.Assert.NumericNotEquals 'Test Assert money 1'      , 922337203685477.5805      , @Var_money1        , 0.0001
   EXEC TST.Assert.NumericNotEquals 'Test Assert money 2'      ,-922337203685477.5806      , @Var_money2        , 0.0001
   EXEC TST.Assert.NumericNotEquals 'Test Assert money 3'      , 1234.5676                 , @Var_money3        , 0.0001
   EXEC TST.Assert.NumericNotEquals 'Test Assert float'        , 1.23456789012343          , @Var_float         , 0.00000000000001
   EXEC TST.Assert.NumericNotEquals 'Test Assert real'         , 1.234565                  , @Var_real          , 0.0000001

   EXEC TST.Assert.NumericNotEquals 'Test Assert int'          , 102                       , @Var_int           , 1

END
GO

-- =======================================================================
-- In depth test of passing Assert.NumericNotEquals
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNumNotEqualsTrue
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertNumNotEqualsTrue',
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNumNotEqualsTrue', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='%Test Assert.NumericNotEquals in SQLTest_AssertNumNotEqualsTrue%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO



-- =======================================================================
-- In depth test of failing Assert.NumericNotEquals
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNumNotEqualsFalse
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertNumNotEqualsFalse' ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNumNotEqualsFalse', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.NumericNotEquals in SQLTest_AssertNumNotEqualsFalse%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.NumericNotEquals when NULL is used for 
-- the @ExpectedValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNumNotEqualsExpectedParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                       ,
      @TestName            = 'SQLTest_AssertNumNotEqualsExpectedParamIsNull'  ,
      @ResultsFormat       = 'None'                                     ,
      @CleanTemporaryData  = 0                                          ,
      @TestSessionId       = @TestSessionId OUT                         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNumNotEqualsExpectedParamIsNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='Invalid call to Assert.NumericNotEquals. %Test Assert.NumericNotEquals in SQLTest_AssertNumNotEqualsExpectedParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.NumericNotEquals when NULL is used for 
-- the @ActualValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNumNotEqualsActualParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertNumNotEqualsActualParamIsNull' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNumNotEqualsActualParamIsNull', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.NumericNotEquals in SQLTest_AssertNumNotEqualsActualParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.NumericNotEquals when NULL is used for 
-- both @ExpectedValue and @ActualValue parameters.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNumNotEqualsBothParamsAreNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertNumNotEqualsBothParamsAreNull' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNumNotEqualsBothParamsAreNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='%Test Assert.NumericNotEquals in SQLTest_AssertNumNotEqualsBothParamsAreNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of passing Assert.NumericNotEquals when ContextMessage is NULL.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNumNotEqualsNullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertNumNotEqualsNullContext' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNumNotEqualsNullContext', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='Assert.NumericNotEquals passed. ^[^]%',
         @EscapeCharacter='^'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.NumericNotEquals for each datatype. 
-- Note that we are running an entire suite implemented in TSTCheck
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNumNotEqualsFalseByDataType
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @SProcNames           varchar(1000)
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheck'        ,
      @SuiteName           = 'AssertNumNotEqualsFail'          ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors              @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists          @TestSessionId=@TestSessionId, @SuiteName='AssertNumNotEqualsFail'
   
   SET @SProcNames = 
            'SQLTest_AssertNumNotEqualsFail#numeric,' + 
            'SQLTest_AssertNumNotEqualsFail#decimal,' + 
            'SQLTest_AssertNumNotEqualsFail#smallmoney,' + 
            'SQLTest_AssertNumNotEqualsFail#int,' + 
            'SQLTest_AssertNumNotEqualsFail#money,' + 
            'SQLTest_AssertNumNotEqualsFail#float,' + 
            'SQLTest_AssertNumNotEqualsFail#real'

   EXEC dbo.ValidateOnlyGivenTestExists               @TestSessionId=@TestSessionId, @SProcsNames=@SProcNames, @SProcType='Test'
   
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNumNotEqualsFail#numeric'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NumericNotEquals in suite AssertNumNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNumNotEqualsFail#decimal'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NumericNotEquals in suite AssertNumNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNumNotEqualsFail#smallmoney'   , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NumericNotEquals in suite AssertNumNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNumNotEqualsFail#int'          , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NumericNotEquals in suite AssertNumNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNumNotEqualsFail#money'        , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NumericNotEquals in suite AssertNumNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNumNotEqualsFail#float'        , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NumericNotEquals in suite AssertNumNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertNumNotEqualsFail#real'         , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.NumericNotEquals in suite AssertNumNotEqualsFail%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Tests the behavior of passing Assert.FloatEquals by calling it directly.
-- Note that we have more in depth validation for Assert.FloatEquals.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#DirectCall_AssertFloatEqualsAgainstLiteralValues
AS
BEGIN

   DECLARE @Var_numeric             numeric(38,15)    
   DECLARE @Var_decimal             decimal(38,15)    
   DECLARE @Var_smallmoney1         smallmoney 
   DECLARE @Var_smallmoney2         smallmoney 
   DECLARE @Var_smallmoney3         smallmoney 
   DECLARE @Var_money1              money      
   DECLARE @Var_money2              money      
   DECLARE @Var_money3              money      
   DECLARE @Var_float               float      
   DECLARE @Var_real                real       
   DECLARE @Var_int                 int        

   SET @Var_numeric                 = CAST(12345678901234567890123.456789012345678 AS numeric(38,15)   )
   SET @Var_decimal                 = CAST(12345678901234567890123.456789012345678 AS decimal(38,15)   )
   SET @Var_smallmoney1             = CAST( 214748.3647 AS smallmoney                )
   SET @Var_smallmoney2             = CAST(-214748.3648  AS smallmoney               )
   SET @Var_smallmoney3             = CAST(1234.5678  AS smallmoney                  )
   SET @Var_money1                  = CAST( 922337203685477.5807 AS money            )
   SET @Var_money2                  = CAST(-922337203685477.5808 AS money            )
   SET @Var_money3                  = CAST(1234.5678 AS money                        )
   SET @Var_float                   = CAST(1.23456789012345 AS float                 )
   SET @Var_real                    = CAST(1.234567 AS real                          )
   SET @Var_int                     = CAST(100 AS int                                )

   EXEC TST.Assert.FloatEquals 'Test Assert numeric'      , 12345678901234567890123.456789012345678 , @Var_numeric       , 0
   EXEC TST.Assert.FloatEquals 'Test Assert decimal'      , 12345678901234567890123.456789012345678 , @Var_decimal       , 0
   EXEC TST.Assert.FloatEquals 'Test Assert smallmoney 1' ,  214748.3647              , @Var_smallmoney1   , 0
   EXEC TST.Assert.FloatEquals 'Test Assert smallmoney 2' , -214748.3648              , @Var_smallmoney2   , 0
   EXEC TST.Assert.FloatEquals 'Test Assert smallmoney 3' , 1234.5678                 , @Var_smallmoney3   , 0
   EXEC TST.Assert.FloatEquals 'Test Assert money 1'      , 922337203685477.5807      , @Var_money1        , 0
   EXEC TST.Assert.FloatEquals 'Test Assert money 2'      ,-922337203685477.5808      , @Var_money2        , 0
   EXEC TST.Assert.FloatEquals 'Test Assert money 3'      , 1234.5678                 , @Var_money3        , 0
   EXEC TST.Assert.FloatEquals 'Test Assert float'        , 1.23456789012345          , @Var_float         , 0
   EXEC TST.Assert.FloatEquals 'Test Assert real'         , 1.234567                  , @Var_real          , 0.0000001

   EXEC TST.Assert.FloatEquals 'Test Assert int'          , 100                       , @Var_int           , 0

END
GO

-- =======================================================================
-- Tests the behavior of passing Assert.FloatEquals by calling it directly.
-- Note that we have more in depth validation for Assert.FloatEquals.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#DirectCall_AssertFloatEqualsToleranceAgainstLiteralValues
AS
BEGIN

   DECLARE @Var_numeric             numeric(38,15)    
   DECLARE @Var_decimal             decimal(38,15)    
   DECLARE @Var_smallmoney          smallmoney 
   DECLARE @Var_money               money      
   DECLARE @Var_float               float      
   DECLARE @Var_real                real       

   SET @Var_numeric                 = CAST(12345678901234567890123.456789012345678 AS numeric(38,15)   )
   SET @Var_decimal                 = CAST(12345678901234567890123.456789012345678 AS decimal(38,15)   )
   SET @Var_smallmoney              = CAST(1234.5678  AS smallmoney               )
   SET @Var_money                   = CAST(1234.5678 AS money             )
   SET @Var_float                   = CAST(1.23456789012345 AS float                 )
   SET @Var_real                    = CAST(1.234567 AS real                          )

   EXEC TST.Assert.FloatEquals 'Test Assert numeric'      , 12345678901234567890123.456789012345670 , @Var_numeric       , 0.00000000000001
   EXEC TST.Assert.FloatEquals 'Test Assert decimal'      , 12345678901234567890123.456789012345670 , @Var_decimal       , 0.00000000000001
   EXEC TST.Assert.FloatEquals 'Test Assert smallmoney'   , 1234.567         , @Var_smallmoney    , 0.001
   EXEC TST.Assert.FloatEquals 'Test Assert money'        , 1234.567         , @Var_money         , 0.001
   EXEC TST.Assert.FloatEquals 'Test Assert float'        , 1.234            , @Var_float         , 0.001
   EXEC TST.Assert.FloatEquals 'Test Assert real'         , 1.234            , @Var_real          , 0.001

END
GO



-- =======================================================================
-- In depth test of passing Assert.FloatEquals
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertFloatEqualsTrue
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertFloatEqualsTrue',
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertFloatEqualsTrue', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='%Test Assert.FloatEquals in SQLTest_AssertFloatEqualsTrue ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.FloatEquals
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertFloatEqualsFalse
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertFloatEqualsFalse' ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertFloatEqualsFalse', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.FloatEquals in SQLTest_AssertFloatEqualsFalse ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.FloatEquals when NULL is used for 
-- the @ExpectedValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertFloatEqualsExpectedParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                       ,
      @TestName            = 'SQLTest_AssertFloatEqualsExpectedParamIsNull'  ,
      @ResultsFormat       = 'None'                                     ,
      @CleanTemporaryData  = 0                                          ,
      @TestSessionId       = @TestSessionId OUT                         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertFloatEqualsExpectedParamIsNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='Invalid call to Assert.FloatEquals. %Test Assert.FloatEquals in SQLTest_AssertFloatEqualsExpectedParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.FloatEquals when NULL is used for 
-- the @ActualValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertFloatEqualsActualParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertFloatEqualsActualParamIsNull' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertFloatEqualsActualParamIsNull', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.FloatEquals in SQLTest_AssertFloatEqualsActualParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- =======================================================================
-- In depth test of failing Assert.FloatEquals when NULL is used for 
-- both @ExpectedValue and @ActualValue parameters.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertFloatEqualsBothParamsAreNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertFloatEqualsBothParamsAreNull' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertFloatEqualsBothParamsAreNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='%Test Assert.FloatEquals in SQLTest_AssertFloatEqualsBothParamsAreNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of passing Assert.FloatEquals when ContextMessage is NULL.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertFloatEqualsNullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertFloatEqualsNullContext' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertFloatEqualsNullContext', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='Assert.FloatEquals passed. ^[^]%',
         @EscapeCharacter='^'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.FloatEquals for each datatype. 
-- Note that we are running an entire suite implemented in TSTCheck
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertFloatEqualsFalseByDataType
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @SProcNames           varchar(1000)
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheck'        ,
      @SuiteName           = 'AssertFloatEqualsFail'          ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors              @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists          @TestSessionId=@TestSessionId, @SuiteName='AssertFloatEqualsFail'
   
   SET @SProcNames = 
            'SQLTest_AssertFloatEqualsFail#numeric,' + 
            'SQLTest_AssertFloatEqualsFail#decimal,' + 
            'SQLTest_AssertFloatEqualsFail#smallmoney,' + 
            'SQLTest_AssertFloatEqualsFail#int,' + 
            'SQLTest_AssertFloatEqualsFail#money,' + 
            'SQLTest_AssertFloatEqualsFail#float,' + 
            'SQLTest_AssertFloatEqualsFail#real'

   EXEC dbo.ValidateOnlyGivenTestExists               @TestSessionId=@TestSessionId, @SProcsNames=@SProcNames, @SProcType='Test'
   
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertFloatEqualsFail#numeric'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.FloatEquals in suite AssertFloatEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertFloatEqualsFail#decimal'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.FloatEquals in suite AssertFloatEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertFloatEqualsFail#smallmoney'   , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.FloatEquals in suite AssertFloatEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertFloatEqualsFail#int'          , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.FloatEquals in suite AssertFloatEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertFloatEqualsFail#money'        , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.FloatEquals in suite AssertFloatEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertFloatEqualsFail#float'        , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.FloatEquals in suite AssertFloatEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertFloatEqualsFail#real'         , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.FloatEquals in suite AssertFloatEqualsFail%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- =======================================================================
-- Tests the behavior of passing Assert.FloatNotEquals by calling it directly.
-- Note that we have more in depth validation for Assert.FloatNotEquals.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#DirectCall_AssertFloatNotEqualsAgainstLiteralValues
AS
BEGIN

   DECLARE @Var_numeric             numeric(38,15)    
   DECLARE @Var_decimal             decimal(38,15)    
   DECLARE @Var_smallmoney1         smallmoney 
   DECLARE @Var_smallmoney2         smallmoney 
   DECLARE @Var_smallmoney3         smallmoney 
   DECLARE @Var_money1              money      
   DECLARE @Var_money2              money      
   DECLARE @Var_money3              money      
   DECLARE @Var_float               float      
   DECLARE @Var_real                real       
   DECLARE @Var_int                 int        

   SET @Var_numeric                 = CAST(1234567890.12345 AS numeric(15,5)   )
   SET @Var_decimal                 = CAST(1234567890.12345 AS decimal(15,5)   )
   SET @Var_smallmoney1             = CAST( 214748.3647 AS smallmoney          )
   SET @Var_smallmoney2             = CAST(-214748.3648  AS smallmoney         )
   SET @Var_smallmoney3             = CAST(1234.5678  AS smallmoney            )
   SET @Var_money1                  = CAST( 12345678901.2345 AS money          )
   SET @Var_money2                  = CAST(-12345678901.2345 AS money          )
   SET @Var_money3                  = CAST(1234.5678 AS money                  )
   SET @Var_float                   = CAST(1.23456789012345 AS float           )
   SET @Var_real                    = CAST(1.234567 AS real                    )
   SET @Var_int                     = CAST(100 AS int                          )

   EXEC TST.Assert.FloatNotEquals 'Test Assert numeric'      , 1234567890.12343, @Var_numeric       , 0.00001
   EXEC TST.Assert.FloatNotEquals 'Test Assert decimal'      , 1234567890.12343, @Var_decimal       , 0.00001
   EXEC TST.Assert.FloatNotEquals 'Test Assert smallmoney 1' ,  214748.3645              , @Var_smallmoney1   , 0.0001
   EXEC TST.Assert.FloatNotEquals 'Test Assert smallmoney 2' , -214748.3646              , @Var_smallmoney2   , 0.0001
   EXEC TST.Assert.FloatNotEquals 'Test Assert smallmoney 3' , 1234.5676                 , @Var_smallmoney3   , 0.0001
   EXEC TST.Assert.FloatNotEquals 'Test Assert money 1'      , 12345678901.2343          , @Var_money1        , 0.0001
   EXEC TST.Assert.FloatNotEquals 'Test Assert money 2'      ,-12345678901.2343          , @Var_money2        , 0.0001
   EXEC TST.Assert.FloatNotEquals 'Test Assert money 3'      , 1234.5676                 , @Var_money3        , 0.0001
   EXEC TST.Assert.FloatNotEquals 'Test Assert float'        , 1.23456789012343          , @Var_float         , 0.00000000000001
   EXEC TST.Assert.FloatNotEquals 'Test Assert real'         , 1.234565                  , @Var_real          , 0.0000001

   EXEC TST.Assert.FloatNotEquals 'Test Assert int'          , 101                       , @Var_int           , 0

END
GO

-- =======================================================================
-- In depth test of passing Assert.FloatNotEquals
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertFloatNotEqualsTrue
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertFloatNotEqualsTrue',
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertFloatNotEqualsTrue', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='%Test Assert.FloatNotEquals in SQLTest_AssertFloatNotEqualsTrue ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- =======================================================================
-- In depth test of failing Assert.FloatNotEquals
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertFloatNotEqualsFalse
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertFloatNotEqualsFalse' ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertFloatNotEqualsFalse', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.FloatNotEquals in SQLTest_AssertFloatNotEqualsFalse ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.FloatNotEquals when NULL is used for 
-- the @ExpectedValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertFloatNotEqualsExpectedParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                       ,
      @TestName            = 'SQLTest_AssertFloatNotEqualsExpectedParamIsNull'  ,
      @ResultsFormat       = 'None'                                     ,
      @CleanTemporaryData  = 0                                          ,
      @TestSessionId       = @TestSessionId OUT                         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertFloatNotEqualsExpectedParamIsNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='Invalid call to Assert.FloatNotEquals. %Test Assert.FloatNotEquals in SQLTest_AssertFloatNotEqualsExpectedParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.FloatNotEquals when NULL is used for 
-- the @ActualValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertFloatNotEqualsActualParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertFloatNotEqualsActualParamIsNull' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertFloatNotEqualsActualParamIsNull', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.FloatNotEquals in SQLTest_AssertFloatNotEqualsActualParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.FloatNotEquals when NULL is used for 
-- both @ExpectedValue and @ActualValue parameters.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertFloatNotEqualsBothParamsAreNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertFloatNotEqualsBothParamsAreNull' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertFloatNotEqualsBothParamsAreNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='%Test Assert.FloatNotEquals in SQLTest_AssertFloatNotEqualsBothParamsAreNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of passing Assert.FloatNotEquals when ContextMessage is NULL.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertFloatNotEqualsNullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertFloatNotEqualsNullContext' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertFloatNotEqualsNullContext', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='Assert.FloatNotEquals passed. ^[^]%',
         @EscapeCharacter='^'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.FloatNotEquals for each datatype. 
-- Note that we are running an entire suite implemented in TSTCheck
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertFloatNotEqualsFalseByDataType
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @SProcNames           varchar(1000)
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheck'        ,
      @SuiteName           = 'AssertFloatNotEqualsFail'          ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors              @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists          @TestSessionId=@TestSessionId, @SuiteName='AssertFloatNotEqualsFail'
   
   SET @SProcNames = 
            'SQLTest_AssertFloatNotEqualsFail#numeric,' + 
            'SQLTest_AssertFloatNotEqualsFail#decimal,' + 
            'SQLTest_AssertFloatNotEqualsFail#smallmoney,' + 
            'SQLTest_AssertFloatNotEqualsFail#int,' + 
            'SQLTest_AssertFloatNotEqualsFail#money,' + 
            'SQLTest_AssertFloatNotEqualsFail#float,' + 
            'SQLTest_AssertFloatNotEqualsFail#real'

   EXEC dbo.ValidateOnlyGivenTestExists               @TestSessionId=@TestSessionId, @SProcsNames=@SProcNames, @SProcType='Test'
   
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertFloatNotEqualsFail#numeric'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.FloatNotEquals in suite AssertFloatNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertFloatNotEqualsFail#decimal'      , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.FloatNotEquals in suite AssertFloatNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertFloatNotEqualsFail#smallmoney'   , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.FloatNotEquals in suite AssertFloatNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertFloatNotEqualsFail#int'          , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.FloatNotEquals in suite AssertFloatNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertFloatNotEqualsFail#money'        , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.FloatNotEquals in suite AssertFloatNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertFloatNotEqualsFail#float'        , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.FloatNotEquals in suite AssertFloatNotEqualsFail%'
   EXEC dbo.ValidateOnlyOneTestLogEntryLikeExistsForTest  @TestSessionId=@TestSessionId, @TestName = 'SQLTest_AssertFloatNotEqualsFail#real'         , @ExpectedEntryType='F', @ExpectedLogMessage='%Test Assert.FloatNotEquals in suite AssertFloatNotEqualsFail%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Tests the behavior of Assert.IsLike by calling it directly.
-- Note that we have more in depth validation for Assert.IsLike.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#DirectCall_AssertLike
AS
BEGIN
   EXEC TST.Assert.IsLike 'Test TST.Assert.IsLike', 'abcde 1234' , 'abcde 1234'
   EXEC TST.Assert.IsLike 'Test TST.Assert.IsLike', 'ab%'        , 'abcde 1234'
   EXEC TST.Assert.IsLike 'Test TST.Assert.IsLike', '%1234'      , 'abcde 1234'
   EXEC TST.Assert.IsLike 'Test TST.Assert.IsLike', '%e 1%'      , 'abcde 1234'
END
GO

-- =======================================================================
-- In depth test of passing Assert.IsLike
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertLikeTrue
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'     ,
      @TestName            = 'SQLTest_AssertLikeTrue' ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertLikeTrue', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='%Test Assert.IsLike in SQLTest_AssertLikeTrue ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.IsLike
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertLikeFalse
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'     ,
      @TestName            = 'SQLTest_AssertLikeFalse',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertLikeFalse', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.IsLike in SQLTest_AssertLikeFalse ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.IsLike when NULL is used for 
-- the @ExpectedLikeValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertLikeExpectedParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertLikeExpectedParamIsNull' ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertLikeExpectedParamIsNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='Invalid call to Assert.IsLike. %Test Assert.IsLike in SQLTest_AssertLikeExpectedParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.IsLike when NULL is used for 
-- the @ActualValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertLikeActualParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertLikeActualParamIsNull'   ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertLikeActualParamIsNull', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.IsLike in SQLTest_AssertLikeActualParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.IsLike when NULL is used for 
-- both @ExpectedLikeValue and @ActualValue parameters.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertLikeBothParamsAreNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertLikeBothParamsAreNull'   ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertLikeBothParamsAreNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='%Test Assert.IsLike in SQLTest_AssertLikeBothParamsAreNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of passing Assert.IsLike when ContextMessage is NULL.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertLikeNullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertLikeNullContext'   ,
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertLikeNullContext', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='Assert.IsLike passed. ^[^]%',
         @EscapeCharacter= '^'

   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Tests the behavior of Assert.IsNotLike by calling it directly.
-- Note that we have more in depth validation for Assert.IsNotLike.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#DirectCall_AssertNotLike
AS
BEGIN
   EXEC TST.Assert.IsNotLike 'Test TST.Assert.IsNotLike', 'abcde 0000' , 'abcde 1234'
   EXEC TST.Assert.IsNotLike 'Test TST.Assert.IsNotLike', 'ab%0'       , 'abcde 1234'
   EXEC TST.Assert.IsNotLike 'Test TST.Assert.IsNotLike', '%x 1234'    , 'abcde 1234'
   EXEC TST.Assert.IsNotLike 'Test TST.Assert.IsNotLike', '%x 1%'      , 'abcde 1234'
END
GO

-- =======================================================================
-- In depth test of passing Assert.IsNotLike
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotLikeTrue
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertNotLikeTrue' ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNotLikeTrue', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='%Test Assert.IsNotLike in SQLTest_AssertNotLikeTrue ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of passing Assert.IsNotLike
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotLikeFalse
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertNotLikeFalse',
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNotLikeFalse', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.IsNotLike in SQLTest_AssertNotLikeFalse ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.IsNotLike when NULL is used for 
-- the @ExpectedLikeValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotLikeExpectedParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                       ,
      @TestName            = 'SQLTest_AssertNotLikeExpectedParamIsNull' ,
      @ResultsFormat       = 'None'                                     ,
      @CleanTemporaryData  = 0                                          ,
      @TestSessionId       = @TestSessionId OUT                         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNotLikeExpectedParamIsNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='Invalid call to Assert.IsNotLike. %Test Assert.IsNotLike in SQLTest_AssertNotLikeExpectedParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.IsNotLike when NULL is used for 
-- the @ActualValue parameter.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotLikeActualParamIsNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertNotLikeActualParamIsNull',
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNotLikeActualParamIsNull', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.IsNotLike in SQLTest_AssertNotLikeActualParamIsNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.IsNotLike when NULL is used for 
-- both @ExpectedLikeValue and @ActualValue parameters.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotLikeBothParamsAreNull
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertNotLikeBothParamsAreNull',
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNotLikeBothParamsAreNull', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='%Test Assert.IsNotLike in SQLTest_AssertNotLikeBothParamsAreNull%'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of passing Assert.IsNotLike when ContextMessage is NULL.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertNotLikeNullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'                    ,
      @TestName            = 'SQLTest_AssertNotLikeNullContext',
      @ResultsFormat       = 'None'                                  ,
      @CleanTemporaryData  = 0                                       ,
      @TestSessionId       = @TestSessionId OUT                      ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertNotLikeNullContext', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='Assert.IsNotLike passed. ^[^]%',
         @EscapeCharacter= '^'
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO



-- =======================================================================
-- Tests the behavior of Assert.IsNull by calling it directly.
-- Note that we have more in depth validation for Assert.IsNull.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#DirectCall_AssertIsNull
AS
BEGIN
   EXEC TST.Assert.IsNull 'Test TST.Assert.IsNull', NULL
END
GO

-- =======================================================================
-- In depth test of passing Assert.IsNull
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertIsNullTrue
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertIsNullTrue'  ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertIsNullTrue', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='%Test Assert.IsNull in SQLTest_AssertIsNullTrue ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.IsNull
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertIsNullFalse
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertIsNullFalse' ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertIsNullFalse', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.IsNull in SQLTest_AssertIsNullFalse ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of passing Assert.IsNull when ContextMessage is Null
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertIsNullNullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'        ,
      @TestName            = 'SQLTest_AssertIsNullNullContext' ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertIsNullNullContext', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='Assert.IsNull passed. ^[^]%',
         @EscapeCharacter= '^'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Tests the behavior of Assert.IsNotNull by calling it directly.
-- Note that we have more in depth validation for Assert.IsNotNull.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#DirectCall_AssertIsNotNull
AS
BEGIN
   EXEC TST.Assert.IsNotNull 'Test TST.Assert.IsNotNull', 1
END
GO

-- =======================================================================
-- In depth test of passing Assert.IsNotNull
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertIsNotNullTrue
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'           ,
      @TestName            = 'SQLTest_AssertIsNotNullTrue'  ,
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertIsNotNullTrue', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='%Test Assert.IsNotNull in SQLTest_AssertIsNotNullTrue ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of failing Assert.IsNotNull
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertIsNotNullFalse
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'           ,
      @TestName            = 'SQLTest_AssertIsNotNullFalse' ,
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertIsNotNullFalse', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.IsNotNull in SQLTest_AssertIsNotNullFalse ĂÎÂȘȚăîâșț%'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- In depth test of passing Assert.IsNotNull when ContextMesage is NULL.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TST_API#AssertIsNotNullNullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'           ,
      @TestName            = 'SQLTest_AssertIsNotNullNullContext' ,
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults   
         @TestSessionId=@TestSessionId,
         @SuiteName=NULL,
         @SProcName='SQLTest_AssertIsNotNullNullContext', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='Assert.IsNotNull passed. ^[^]%',
         @EscapeCharacter= '^'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- END BASIC features. API testing
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- START TRANSACTION related features.
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- =======================================================================
-- Testing the simple case - the tested procedure has no transactions.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Test_NoTransaction
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Test_NoTransactions#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Test_NoTransactions'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Test_NoTransactions#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Test_NoTransactions', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Test_NoTransactions', @SProcType='Teardown'

   -- Make sure that all the messages from all tests in this suite were recorded.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_NoTransactions#Test', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Test_NoTransactions'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_NoTransactions#Test', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Test_NoTransactions#Test%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_NoTransactions#Test', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Test_NoTransactions'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_NoTransactions#Test', @ExpectedLogEntryCount=3
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where the tested procedure has a transaction and does
-- a ROLLBACK.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Proc_Test_SavePointTransaction
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Test_SavePointTransaction#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Test_SavePointTransaction'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Test_SavePointTransaction#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Test_SavePointTransaction', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Test_SavePointTransaction', @SProcType='Teardown'

   -- Make sure that all the messages from all tests in this suite were recorded.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_SavePointTransaction#Test', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Test_SavePointTransaction'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_SavePointTransaction#Test', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Test_SavePointTransaction#Test'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_SavePointTransaction#Test', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Proc_Test_TranRollback#Test%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_SavePointTransaction#Test', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Test_SavePointTransaction'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_SavePointTransaction#Test', @ExpectedLogEntryCount=4

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- =======================================================================
-- Testing the case where the tested procedure has a transaction and does
-- a ROLLBACK.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Proc_Test_TranRollback
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Proc_Test_TranRollback#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Proc_Test_TranRollback'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Proc_Test_TranRollback#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Proc_Test_TranRollback', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Proc_Test_TranRollback', @SProcType='Teardown'

   SET @ExpectedLogMessage='ROLLBACK TRANSACTION detected in procedure ''InsertTestEntryAndRollback1''. ' + 
               'All other TST messages logged during this test and previous to this error were lost. ' + 
               'Please disable the TST rollback if you expect the tested procedure to use ROLLBACK TRANSACTION. ' + 
               'To disable TST rollback create a stored procedure called TSTConfig in the database where you ' +
               'have the test procedures. Inside TSTConfig call ' + 
               '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. ' + 
               'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
               'See TST documentation for more details.'   

   -- Note that some log entries are lost due to the rollback made by the tested procedure.
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranRollback#Test', @LogIndex=1, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 266,%InsertTestEntryAndRollback1%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranRollback#Test', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranRollback#Test', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction was rolled back during the test procedure ''[TSTCheckTran].[dbo].[SQLTest_Proc_Test_TranRollback#Test]''. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranRollback#Test', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Test_TranRollback'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranRollback#Test', @ExpectedLogEntryCount=4

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where the tested procedure has a transaction and does
-- a ROLLBACK but TST rollback is disabled via TSTConfig.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Proc_Test_TranRollbackSRDisabled
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'        ,
      @TestName            = 'SQLTest_Proc_Test_TranRollbackSRDisabled#Test'  ,
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Proc_Test_TranRollbackSRDisabled'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Proc_Test_TranRollbackSRDisabled#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Proc_Test_TranRollbackSRDisabled', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Proc_Test_TranRollbackSRDisabled', @SProcType='Teardown'

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranRollbackSRDisabled#Test', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Proc_Test_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranRollbackSRDisabled#Test', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Proc_Test_TranRollbackSRDisabled#Test'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranRollbackSRDisabled#Test', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Proc_Test_TranRollbackSRDisabled#Test%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranRollbackSRDisabled#Test', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Test_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranRollbackSRDisabled#Test', @ExpectedLogEntryCount=4

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where a suite has three tests. The second test 
-- will do a BEGIN TRANSACTION / ROLLBACK.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Proc_Test_Multi_TranRollback
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
      
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @SuiteName           = 'Proc_Test_Multi_TranRollback'  ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Proc_Test_Multi_TranRollback'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Proc_Test_Multi_TranRollback#TestA,SQLTest_Proc_Test_Multi_TranRollback#TestB,SQLTest_Proc_Test_Multi_TranRollback#TestC', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Proc_Test_Multi_TranRollback', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Proc_Test_Multi_TranRollback', @SProcType='Teardown'

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction
   SET @ExpectedLogMessage='ROLLBACK TRANSACTION detected in procedure ''InsertTestEntryAndRollback3''. ' + 
               'All other TST messages logged during this test and previous to this error were lost. ' + 
               'Please disable the TST rollback if you expect the tested procedure to use ROLLBACK TRANSACTION. ' + 
               'To disable TST rollback create a stored procedure called TSTConfig in the database where you ' +
               'have the test procedures. Inside TSTConfig call ' + 
               '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. ' + 
               'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
               'See TST documentation for more details.'   

   -- Make sure that no log entries recorded during SQLTest_Proc_Test_Multi_TranRollback#TestA are lost.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollback#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Proc_Test_Multi_TranRollback'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollback#TestA', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Proc_Test_Multi_TranRollback#TestA%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollback#TestA', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Test_Multi_TranRollback'   
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollback#TestA', @ExpectedLogEntryCount=3
   
   -- Note that some log entries made during SQLTest_Proc_Test_Multi_TranRollback#TestB are lost due to the rollback made by the tested procedure.
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollback#TestB', @LogIndex=1, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 266,%InsertTestEntryAndRollback3%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollback#TestB', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollback#TestB', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction was rolled back during the test procedure ''[TSTCheckTran].[dbo].[SQLTest_Proc_Test_Multi_TranRollback#TestB]''. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollback#TestB', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Test_Multi_TranRollback'   
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollback#TestB', @ExpectedLogEntryCount=4
   
   -- Make sure that no log entries recorded during SQLTest_Proc_Test_Multi_TranRollback#TestC are lost.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollback#TestC', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Proc_Test_Multi_TranRollback'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollback#TestC', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Proc_Test_Multi_TranRollback#TestC%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollback#TestC', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Test_Multi_TranRollback'   
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollback#TestC', @ExpectedLogEntryCount=3
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where a suite has three tests. The second test 
-- will do a BEGIN TRANSACTION / ROLLBACK but TST rollback is disabled 
-- via TSTConfig.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Proc_Test_Multi_TranRollbackSRDisabled
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @SuiteName           = 'Proc_Test_Multi_TranRollbackSRDisabled'            ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Proc_Test_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestA,SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestB,SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestC', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Proc_Test_Multi_TranRollbackSRDisabled', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Proc_Test_Multi_TranRollbackSRDisabled', @SProcType='Teardown'

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Proc_Test_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestA', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestA%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestA', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Test_Multi_TranRollbackSRDisabled'   
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestA', @ExpectedLogEntryCount=3
   
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Proc_Test_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestB', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestB #1%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestB', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestB #2%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestB', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Test_Multi_TranRollbackSRDisabled'   
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestB', @ExpectedLogEntryCount=4
   
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestC', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Proc_Test_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestC', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestC%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestC', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Test_Multi_TranRollbackSRDisabled'   
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_Multi_TranRollbackSRDisabled#TestC', @ExpectedLogEntryCount=3
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where the tested procedure has a transaction and does 
-- a COMMIT.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Proc_Test_TranCommit
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Proc_Test_TranCommit#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Proc_Test_TranCommit'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Proc_Test_TranCommit#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Proc_Test_TranCommit', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Proc_Test_TranCommit', @SProcType='Teardown'

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranCommit#Test', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Proc_Test_TranCommit'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranCommit#Test', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Proc_Test_TranCommit#Test%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranCommit#Test', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Test_TranCommit'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranCommit#Test', @ExpectedLogEntryCount=3

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where the tested procedure has a transaction and does 
-- a BEGIN TRANSACTION but does not commit or rolback.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Test_TranNewTransaction
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   varchar(max)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Proc_Test_TranBegin#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Proc_Test_TranBegin'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Proc_Test_TranBegin#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Proc_Test_TranBegin', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Proc_Test_TranBegin', @SProcType='Teardown'

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction
   SET @ExpectedLogMessage = 'BEGIN TRANSACTION with no matching COMMIT detected in procedure ''InsertTestEntryAndBeginTran1''.' + 
         ' Please disable the TST rollback if you expect the tested procedure to use BEGIN TRANSACTION with no matching COMMIT. ' + 
         'To disable TST rollback create a stored procedure called TSTConfig in the database where you ' +
         'have the test procedures. Inside TSTConfig call ' + 
         '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. ' + 
         'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
         'See TST documentation for more details.'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranBegin#Test'      , @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Proc_Test_TranBegin'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranBegin#Test'      , @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 266,%InsertTestEntryAndBeginTran1%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranBegin#Test'      , @LogIndex=4, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranBegin#Test'      , @LogIndex=5, @ExpectedLogType='E', @ExpectedLogMessage='The transaction is in an uncommitable state after the test procedure ''[TSTCheckTran].[dbo].[SQLTest_Proc_Test_TranBegin#Test]'' has failed. A rollback was forced. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranBegin#Test'      , @LogIndex=6, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Test_TranBegin'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranBegin#Test'      , @ExpectedLogEntryCount=6

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
  
END
GO

-- =======================================================================
-- Testing the case where the tested procedure has a transaction and does 
-- a BEGIN TRANSACTION, does not commit or rolback but TST rollback 
-- is disabled via TSTConfig.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Test_TranNewTransactionSRDisabled
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   varchar(max)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Proc_Test_TranBeginSRDisabled#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Proc_Test_TranBeginSRDisabled'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Proc_Test_TranBeginSRDisabled#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Proc_Test_TranBeginSRDisabled', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Proc_Test_TranBeginSRDisabled', @SProcType='Teardown'

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction
   SET @ExpectedLogMessage = 'BEGIN TRANSACTION with no matching COMMIT detected in procedure ''InsertTestEntryAndBeginTran2''.' + 
         ' Please disable the TST rollback if you expect the tested procedure to use BEGIN TRANSACTION with no matching COMMIT. ' + 
         'To disable TST rollback create a stored procedure called TSTConfig in the database where you ' +
         'have the test procedures. Inside TSTConfig call ' + 
         '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. ' + 
         'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
         'See TST documentation for more details.'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranBeginSRDisabled#Test'      , @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Proc_Test_TranBeginSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranBeginSRDisabled#Test'      , @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%TestAssert in SQLTest_Proc_Test_TranBeginSRDisabled#Test%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranBeginSRDisabled#Test'      , @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 266,%InsertTestEntryAndBeginTran2%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranBeginSRDisabled#Test'      , @LogIndex=4, @ExpectedLogType='E', @ExpectedLogMessage='The test procedure ''[TSTCheckTran].[dbo].[SQLTest_Proc_Test_TranBeginSRDisabled#Test]'' opened a transaction that is now in an uncommitable state. A rollback was forced. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranBeginSRDisabled#Test'      , @LogIndex=5, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Test_TranBeginSRDisabled'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_TranBeginSRDisabled#Test'      , @ExpectedLogEntryCount=5

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
  
END
GO


-- =======================================================================
-- Testing the case where the setup procedure has a transaction and does
-- a ROLLBACK.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Proc_Setup_TranRollback
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Proc_Setup_TranRollback#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Proc_Setup_TranRollback'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Proc_Setup_TranRollback#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Proc_Setup_TranRollback', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Proc_Setup_TranRollback', @SProcType='Teardown'

   SET @ExpectedLogMessage='ROLLBACK TRANSACTION detected in procedure ''InsertTestEntryAndRollbackS1''. ' + 
               'All other TST messages logged during this test and previous to this error were lost. ' + 
               'Please disable the TST rollback if you expect the tested procedure to use ROLLBACK TRANSACTION. ' + 
               'To disable TST rollback create a stored procedure called TSTConfig in the database where you ' +
               'have the test procedures. Inside TSTConfig call ' + 
               '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. ' + 
               'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
               'See TST documentation for more details.'   

   -- Note that some log entries are lost due to the rollback made by the tested procedure.
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranRollback#Test', @LogIndex=1, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 266,%InsertTestEntryAndRollbackS1%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranRollback#Test', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranRollback#Test', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction was rolled back during the setup procedure ''[TSTCheckTran].[dbo].[SQLTest_SETUP_Proc_Setup_TranRollback]''. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranRollback#Test', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Setup_TranRollback'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranRollback#Test', @ExpectedLogEntryCount=4

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where the setup procedure has a transaction and does
-- a ROLLBACK but TST rollback is disabled via TSTConfig.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Proc_Setup_TranRollbackSRDisabled
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Proc_Setup_TranRollbackSRDisabled#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Proc_Setup_TranRollbackSRDisabled'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Proc_Setup_TranRollbackSRDisabled#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Proc_Setup_TranRollbackSRDisabled', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Proc_Setup_TranRollbackSRDisabled', @SProcType='Teardown'

   -- Note that some log entries are lost due to the rollback made by the tested procedure.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranRollbackSRDisabled#Test', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Proc_Setup_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranRollbackSRDisabled#Test', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_SETUP_Proc_Setup_TranRollbackSRDisabled%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranRollbackSRDisabled#Test', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Proc_Setup_TranRollbackSRDisabled#Test%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranRollbackSRDisabled#Test', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Setup_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranRollbackSRDisabled#Test', @ExpectedLogEntryCount=4

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where the setup procedure has a transaction and does 
-- a BEGIN TRANSACTION but does not commit or rolback.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Proc_Setup_TranNewTransaction
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   varchar(max)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Proc_Setup_TranBegin#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Proc_Setup_TranBegin'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Proc_Setup_TranBegin#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Proc_Setup_TranBegin', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Proc_Setup_TranBegin', @SProcType='Teardown'

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction
   SET @ExpectedLogMessage = 'BEGIN TRANSACTION with no matching COMMIT detected in procedure ''InsertTestEntryAndBeginTranS1''.' + 
         ' Please disable the TST rollback if you expect the tested procedure to use BEGIN TRANSACTION with no matching COMMIT. ' + 
         'To disable TST rollback create a stored procedure called TSTConfig in the database where you ' +
         'have the test procedures. Inside TSTConfig call ' + 
         '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. ' + 
         'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
         'See TST documentation for more details.'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranBegin#Test'      , @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Proc_Setup_TranBegin'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranBegin#Test'      , @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 266,%InsertTestEntryAndBeginTranS1%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranBegin#Test'      , @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranBegin#Test'      , @LogIndex=4, @ExpectedLogType='E', @ExpectedLogMessage='The transaction is in an uncommitable state after the setup procedure ''[TSTCheckTran].[dbo].[SQLTest_SETUP_Proc_Setup_TranBegin]'' has failed. A rollback was forced. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranBegin#Test'      , @LogIndex=5, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Setup_TranBegin'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Setup_TranBegin#Test'      , @ExpectedLogEntryCount=5

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
  
END
GO

-- =======================================================================
-- Testing the case where the teardown procedure has a transaction and does
-- a ROLLBACK.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Proc_Teardown_TranRollback
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Proc_Teardown_TranRollback#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Proc_Teardown_TranRollback'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Proc_Teardown_TranRollback#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Proc_Teardown_TranRollback', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Proc_Teardown_TranRollback', @SProcType='Teardown'

   SET @ExpectedLogMessage='ROLLBACK TRANSACTION detected in procedure ''InsertTestEntryAndRollbackT1''. ' + 
               'All other TST messages logged during this test and previous to this error were lost. ' + 
               'Please disable the TST rollback if you expect the tested procedure to use ROLLBACK TRANSACTION. ' + 
               'To disable TST rollback create a stored procedure called TSTConfig in the database where you ' +
               'have the test procedures. Inside TSTConfig call ' + 
               '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. ' + 
               'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
               'See TST documentation for more details.'   

   -- Note that some log entries are lost due to the rollback made by the tested procedure.
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranRollback#Test', @LogIndex=1, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 266,%InsertTestEntryAndRollbackT1%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranRollback#Test', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranRollback#Test', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction was rolled back during the teardown procedure ''[TSTCheckTran].[dbo].[SQLTest_TEARDOWN_Proc_Teardown_TranRollback]''.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranRollback#Test', @ExpectedLogEntryCount=3

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where the teardown procedure has a transaction and does
-- a ROLLBACK but TST rollback is disabled via TSTConfig.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Proc_Teardown_TranRollbackSRDisabled
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Proc_Teardown_TranRollbackSRDisabled#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Proc_Teardown_TranRollbackSRDisabled'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Proc_Teardown_TranRollbackSRDisabled#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Proc_Teardown_TranRollbackSRDisabled', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Proc_Teardown_TranRollbackSRDisabled', @SProcType='Teardown'

   SET @ExpectedLogMessage='ROLLBACK TRANSACTION detected in procedure ''InsertTestEntryAndRollbackT2''. ' + 
               'All other TST messages logged during this test and previous to this error were lost. ' + 
               'Please disable the TST rollback if you expect the tested procedure to use ROLLBACK TRANSACTION. ' + 
               'To disable TST rollback create a stored procedure called TSTConfig in the database where you ' +
               'have the test procedures. Inside TSTConfig call ' + 
               '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. ' + 
               'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
               'See TST documentation for more details.'   

   -- Note that some log entries are lost due to the rollback made by the tested procedure.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranRollbackSRDisabled#Test', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Proc_Teardown_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranRollbackSRDisabled#Test', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Proc_Teardown_TranRollbackSRDisabled#Test%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranRollbackSRDisabled#Test', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Teardown_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranRollbackSRDisabled#Test', @LogIndex=4, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Proc_Teardown_TranRollbackSRDisabled%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranRollbackSRDisabled#Test', @ExpectedLogEntryCount=4

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where the teardown procedure has a transaction and does 
-- a BEGIN TRANSACTION but does not commit or rolback.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Proc_Teardown_TranNewTransaction
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   varchar(max)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Proc_Teardown_TranBegin#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Proc_Teardown_TranBegin'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Proc_Teardown_TranBegin#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Proc_Teardown_TranBegin', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Proc_Teardown_TranBegin', @SProcType='Teardown'

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction
   SET @ExpectedLogMessage = 'BEGIN TRANSACTION with no matching COMMIT detected in procedure ''InsertTestEntryAndBeginTranT1''.' + 
         ' Please disable the TST rollback if you expect the tested procedure to use BEGIN TRANSACTION with no matching COMMIT. ' + 
         'To disable TST rollback create a stored procedure called TSTConfig in the database where you ' +
         'have the test procedures. Inside TSTConfig call ' + 
         '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. ' + 
         'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
         'See TST documentation for more details.'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranBegin#Test'      , @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Proc_Teardown_TranBegin'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranBegin#Test'      , @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%TestAssert in SQLTest_Proc_Teardown_TranBegin#Test%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranBegin#Test'      , @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Proc_Teardown_TranBegin'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranBegin#Test'      , @LogIndex=4, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 266,%InsertTestEntryAndBeginTranT1%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranBegin#Test'      , @LogIndex=5, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranBegin#Test'      , @LogIndex=6, @ExpectedLogType='E', @ExpectedLogMessage='The transaction is in an uncommitable state after the teardown procedure ''[TSTCheckTran].[dbo].[SQLTest_TEARDOWN_Proc_Teardown_TranBegin]'' has failed. A rollback was forced.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Teardown_TranBegin#Test'      , @ExpectedLogEntryCount=6

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
  
END
GO

-- =======================================================================
-- Testing the case where the tested procedure causes a trigger that uses 
-- no transactions.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Trigger_Test_NoTransaction
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'              ,
      @TestName            = 'SQLTest_Trigger_NoTransactions#Test',
      @ResultsFormat       = 'None'                               ,
      @CleanTemporaryData  = 0                                    ,
      @TestSessionId       = @TestSessionId OUT                   ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Trigger_NoTransactions'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Trigger_NoTransactions#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Trigger_NoTransactions', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Trigger_NoTransactions', @SProcType='Teardown'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_NoTransactions#Test'      , @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_NoTransactions'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_NoTransactions#Test'      , @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%TestAssert in SQLTest_Trigger_NoTransactions#Test%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_NoTransactions#Test'      , @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Trigger_NoTransactions#Test. Row count in TestTableTRG1%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_NoTransactions#Test'      , @LogIndex=4, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Trigger_NoTransactions#Test. Row count in TriggerLog%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_NoTransactions#Test'      , @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%TestAssert in SQLTest_TEARDOWN_Trigger_NoTransactions%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_NoTransactions#Test'      , @ExpectedLogEntryCount=5

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO


-- =======================================================================
-- Testing the case where the tested procedure causes a trigger that uses 
-- a transaction and does a ROLLBACK.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Trigger_Test_TranRollback
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'     ,
      @TestName            = 'SQLTest_Trigger_Test_TranRollback#Test',
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction
   SET @ExpectedLogMessage='ROLLBACK TRANSACTION detected in procedure ''InsertTestEntryTriggerTransactionRollback''. '+ 
               'All other TST messages logged during this test and previous to this error were lost. ' + 
               'Please disable the TST rollback if you expect the tested procedure to use ROLLBACK TRANSACTION. ' + 
               'To disable TST rollback create a stored procedure called TSTConfig in the database where you have the test procedures. Inside TSTConfig call ' + 
               '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. ' + 
               'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
               'See TST documentation for more details.'
               

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Trigger_Test_TranRollback'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Trigger_Test_TranRollback#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Trigger_Test_TranRollback', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Trigger_Test_TranRollback', @SProcType='Teardown'

   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId, @SProcName='SQLTest_Trigger_Test_TranRollback#Test'      , @LogIndex=1, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId, @SProcName='SQLTest_Trigger_Test_TranRollback#Test'      , @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId, @SProcName='SQLTest_Trigger_Test_TranRollback#Test'      , @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction was rolled back during the test procedure ''[TSTCheckTran].[dbo].[SQLTest_Trigger_Test_TranRollback#Test]''. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId, @SProcName='SQLTest_Trigger_Test_TranRollback#Test'      , @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Test_TranRollback'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId, @SProcName='SQLTest_Trigger_Test_TranRollback#Test'      , @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_TranRollback. Row count in TestTableTRG2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId, @SProcName='SQLTest_Trigger_Test_TranRollback#Test'      , @LogIndex=6, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_TranRollback. Row count in TriggerLog%'
   
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranRollback#Test'      , @ExpectedLogEntryCount=6

   EXEC TST.Internal.CleanSessionData @TestSessionId


END
GO


-- =======================================================================
-- Testing the case where the tested procedure causes a trigger that uses 
-- a transaction and does a ROLLBACK but the TST rollback is disabled.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Trigger_Test_TranRollbackSRDisabled
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'     ,
      @TestName            = 'SQLTest_Trigger_Test_TranRollbackSRDisabled#Test',
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction.
   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Trigger_Test_TranRollbackSRDisabled'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Trigger_Test_TranRollbackSRDisabled#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Trigger_Test_TranRollbackSRDisabled', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Trigger_Test_TranRollbackSRDisabled', @SProcType='Teardown'

   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId, @SProcName='SQLTest_Trigger_Test_TranRollbackSRDisabled#Test'      , @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Test_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId, @SProcName='SQLTest_Trigger_Test_TranRollbackSRDisabled#Test'      , @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is in SQLTest_Trigger_Test_TranRollbackSRDisabled#Test'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId, @SProcName='SQLTest_Trigger_Test_TranRollbackSRDisabled#Test'      , @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId, @SProcName='SQLTest_Trigger_Test_TranRollbackSRDisabled#Test'      , @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Test_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId, @SProcName='SQLTest_Trigger_Test_TranRollbackSRDisabled#Test'      , @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_TranRollbackSRDisabled. Row count in TestTableTRG2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId, @SProcName='SQLTest_Trigger_Test_TranRollbackSRDisabled#Test'      , @LogIndex=6, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_TranRollbackSRDisabled. Row count in TriggerLog%'
   
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranRollbackSRDisabled#Test'      , @ExpectedLogEntryCount=6

   EXEC TST.Internal.CleanSessionData @TestSessionId


END
GO

-- =======================================================================
-- Testing the case where a suite has three tests. The second test 
-- causes a trigger that uses a transaction and does a ROLLBACK.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Trigger_Test_Multi_TranRollback
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
      
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @SuiteName           = 'Trigger_Test_Multi_TranRollback',
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Trigger_Test_Multi_TranRollback'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Trigger_Test_Multi_TranRollback#TestA,SQLTest_Trigger_Test_Multi_TranRollback#TestB,SQLTest_Trigger_Test_Multi_TranRollback#TestC', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Trigger_Test_Multi_TranRollback', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollback', @SProcType='Teardown'

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction
   SET @ExpectedLogMessage='ROLLBACK TRANSACTION detected in procedure ''InsertTestEntryTriggerTransactionRollback''. ' + 
               'All other TST messages logged during this test and previous to this error were lost. ' + 
               'Please disable the TST rollback if you expect the tested procedure to use ROLLBACK TRANSACTION. ' + 
               'To disable TST rollback create a stored procedure called TSTConfig in the database where you ' + 
               'have the test procedures. Inside TSTConfig call ' + 
               '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. ' + 
               'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
               'See TST documentation for more details.'

   -- Make sure that no log entries recorded during SQLTest_Trigger_Test_Multi_TranRollback#TestA are lost.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Test_Multi_TranRollback'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestA', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Trigger_Test_Multi_TranRollback#TestA%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestA', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollback'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestA', @LogIndex=4, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollback. Row count in TestTableTRG2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestA', @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollback. Row count in TriggerLog%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestA', @ExpectedLogEntryCount=5
   
   -- Note that some log entries made during SQLTest_Trigger_Test_Multi_TranRollback#TestB are lost due to the rollback made by the tested procedure.
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestB', @LogIndex=1, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestB', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestB', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction was rolled back during the test procedure ''[TSTCheckTran].[dbo].[SQLTest_Trigger_Test_Multi_TranRollback#TestB]''. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestB', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollback'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestB', @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollback. Row count in TestTableTRG2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestB', @LogIndex=6, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollback. Row count in TriggerLog%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestB', @ExpectedLogEntryCount=6
   
   -- Make sure that no log entries recorded during SQLTest_Trigger_Test_Multi_TranRollback#TestC are lost.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestC', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Test_Multi_TranRollback'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestC', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Trigger_Test_Multi_TranRollback#TestC%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestC', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollback'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestC', @LogIndex=4, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollback. Row count in TestTableTRG2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestC', @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollback. Row count in TriggerLog%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollback#TestC', @ExpectedLogEntryCount=5
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- =======================================================================
-- Testing the case where a suite has three tests. The second test 
-- causes a trigger that uses a transaction and does a ROLLBACK but the 
-- TST rollback is disabled.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Trigger_Test_Multi_TranRollbackSRDisabled
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
      
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @SuiteName           = 'Trigger_Test_Multi_TranRollbackSRDisabled',
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Trigger_Test_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestA,SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB,SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestC', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Trigger_Test_Multi_TranRollbackSRDisabled', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollbackSRDisabled', @SProcType='Teardown'

   -- Make sure that no log entries recorded during SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestA are lost.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Test_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestA', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestA%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestA', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestA', @LogIndex=4, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollbackSRDisabled. Row count in TestTableTRG2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestA', @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollbackSRDisabled. Row count in TriggerLog%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestA', @ExpectedLogEntryCount=5
   
   -- Make sure that no log entries recorded during SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB are lost.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB', @LogIndex= 1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Test_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB', @LogIndex= 2, @ExpectedLogType='L', @ExpectedLogMessage='This is in SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB', @LogIndex= 3, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB', @LogIndex= 4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB', @LogIndex= 5, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollbackSRDisabled. Row count in TestTableTRG2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB', @LogIndex= 6, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollbackSRDisabled. Row count in TriggerLog%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestB', @ExpectedLogEntryCount=6
   
   -- Make sure that no log entries recorded during SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestC are lost.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestC', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Test_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestC', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestC%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestC', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestC', @LogIndex=4, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollbackSRDisabled. Row count in TestTableTRG2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestC', @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Test_Multi_TranRollbackSRDisabled. Row count in TriggerLog%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_Multi_TranRollbackSRDisabled#TestC', @ExpectedLogEntryCount=5
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where the tested procedure causes a trigger that uses 
-- a transaction and does a COMMIT.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Trigger_Test_TranCommit
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Trigger_Test_TranCommit#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Trigger_Test_TranCommit'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Trigger_Test_TranCommit#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Trigger_Test_TranCommit', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Trigger_Test_TranCommit', @SProcType='Teardown'

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranCommit#Test', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Test_TranCommit'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranCommit#Test', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Trigger_Test_TranCommit#Test'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranCommit#Test', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_Trigger_Test_TranCommit#Test%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranCommit#Test', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Test_TranCommit'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranCommit#Test', @ExpectedLogEntryCount=4

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- =======================================================================
-- Testing the case where the tested procedure causes a trigger that 
-- opens a TRANSACTION and leaves it open.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Trigger_Test_TranBegin
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Trigger_Test_TranBegin#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Trigger_Test_TranBegin'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Trigger_Test_TranBegin#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Trigger_Test_TranBegin', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Trigger_Test_TranBegin', @SProcType='Teardown'

   SET @ExpectedLogMessage='BEGIN TRANSACTION with no matching COMMIT detected in procedure ''InsertTestEntryTriggerTransactionBegin''. ' + 
               'Please disable the TST rollback if you expect the tested procedure to use BEGIN TRANSACTION with no matching COMMIT. ' + 
               'To disable TST rollback create a stored procedure called TSTConfig in the database where you '+ 
               'have the test procedures. Inside TSTConfig call ' + 
               '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. '+
               'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
               'See TST documentation for more details.'

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranBegin#Test', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Test_TranBegin'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranBegin#Test', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Trigger_Test_TranBegin#Test'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranBegin#Test', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 266,%InsertTestEntryTriggerTransactionBegin%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranBegin#Test', @LogIndex=4, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranBegin#Test', @LogIndex=5, @ExpectedLogType='E', @ExpectedLogMessage='The transaction is in an uncommitable state after the test procedure ''[TSTCheckTran].[dbo].[SQLTest_Trigger_Test_TranBegin#Test]'' has failed. A rollback was forced. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranBegin#Test', @LogIndex=6, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Test_TranBegin'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranBegin#Test', @ExpectedLogEntryCount=6

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- =======================================================================
-- Testing the case where the tested procedure causes a trigger that 
-- opens a TRANSACTION and leaves it open but TST rollback is disabled 
-- via TSTConfig.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Trigger_Test_TranBeginSRDisabled
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @TestName            = 'SQLTest_Trigger_Test_TranBeginSRDisabled#Test' ,
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Trigger_Test_TranBeginSRDisabled'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Trigger_Test_TranBeginSRDisabled#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Trigger_Test_TranBeginSRDisabled', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Trigger_Test_TranBeginSRDisabled', @SProcType='Teardown'

   SET @ExpectedLogMessage='BEGIN TRANSACTION with no matching COMMIT detected in procedure ''InsertTestEntryTriggerTransactionBegin''. ' + 
               'Please disable the TST rollback if you expect the tested procedure to use BEGIN TRANSACTION with no matching COMMIT. ' + 
               'To disable TST rollback create a stored procedure called TSTConfig in the database where you '+ 
               'have the test procedures. Inside TSTConfig call ' + 
               '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. '+
               'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
               'See TST documentation for more details.'

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranBeginSRDisabled#Test', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Test_TranBeginSRDisabled'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranBeginSRDisabled#Test', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Trigger_Test_TranBeginSRDisabled#Test'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranBeginSRDisabled#Test', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 266,%InsertTestEntryTriggerTransactionBegin%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranBeginSRDisabled#Test', @LogIndex=4, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranBeginSRDisabled#Test', @LogIndex=5, @ExpectedLogType='E', @ExpectedLogMessage='The transaction is in an uncommitable state after the test procedure ''[TSTCheckTran].[dbo].[SQLTest_Trigger_Test_TranBeginSRDisabled#Test]'' has failed. A rollback was forced. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranBeginSRDisabled#Test', @LogIndex=6, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Test_TranBeginSRDisabled'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Test_TranBeginSRDisabled#Test', @ExpectedLogEntryCount=6

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- =======================================================================
-- Testing the case where a suite has three tests. The setup 
-- causes a trigger that uses a transaction and does a ROLLBACK.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Trigger_Setup_Multi_TranRollback
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
      
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @SuiteName           = 'Trigger_Setup_Multi_TranRollback',
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Trigger_Setup_Multi_TranRollback'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Trigger_Setup_Multi_TranRollback#TestA,SQLTest_Trigger_Setup_Multi_TranRollback#TestB,SQLTest_Trigger_Setup_Multi_TranRollback#TestC', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Trigger_Setup_Multi_TranRollback', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollback', @SProcType='Teardown'

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction
   SET @ExpectedLogMessage='ROLLBACK TRANSACTION detected in procedure ''InsertTestEntryTriggerTransactionRollback''. ' + 
               'All other TST messages logged during this test and previous to this error were lost. ' + 
               'Please disable the TST rollback if you expect the tested procedure to use ROLLBACK TRANSACTION. ' + 
               'To disable TST rollback create a stored procedure called TSTConfig in the database where you ' + 
               'have the test procedures. Inside TSTConfig call ' + 
               '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. ' + 
               'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
               'See TST documentation for more details.'

   -- Note that some log entries made during SQLTest_Trigger_Setup_Multi_TranRollback#TestA are lost due to the rollback made by the setup procedure.
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestA', @LogIndex=1, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestA', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestA', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction was rolled back during the setup procedure ''[TSTCheckTran].[dbo].[SQLTest_SETUP_Trigger_Setup_Multi_TranRollback]''. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestA', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollback'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestA', @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollback. Row count in TestTableTRG2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestA', @LogIndex=6, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollback. Row count in TriggerLog%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestA', @ExpectedLogEntryCount=6
   
   -- Note that some log entries made during SQLTest_Trigger_Setup_Multi_TranRollback#TestB are lost due to the rollback made by the setup procedure.
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestB', @LogIndex=1, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestB', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestB', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction was rolled back during the setup procedure ''[TSTCheckTran].[dbo].[SQLTest_SETUP_Trigger_Setup_Multi_TranRollback]''. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestB', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollback'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestB', @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollback. Row count in TestTableTRG2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestB', @LogIndex=6, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollback. Row count in TriggerLog%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestB', @ExpectedLogEntryCount=6
   
   -- Note that some log entries made during SQLTest_Trigger_Setup_Multi_TranRollback#TestA are lost due to the rollback made by the setup procedure.
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestC', @LogIndex=1, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestC', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestC', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction was rolled back during the setup procedure ''[TSTCheckTran].[dbo].[SQLTest_SETUP_Trigger_Setup_Multi_TranRollback]''. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestC', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollback'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestC', @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollback. Row count in TestTableTRG2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestC', @LogIndex=6, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollback. Row count in TriggerLog%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollback#TestC', @ExpectedLogEntryCount=6
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where a suite has three tests. The setup 
-- causes a trigger that uses a transaction and does a ROLLBACK.
-- The TST Rollback is disabled.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Trigger_Setup_Multi_TranRollbackSRDisabled
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
      
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @SuiteName           = 'Trigger_Setup_Multi_TranRollbackSRDisabled',
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Trigger_Setup_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestA,SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestB,SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestC', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Trigger_Setup_Multi_TranRollbackSRDisabled', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollbackSRDisabled', @SProcType='Teardown'


   -- Make sure that no log entries recorded during SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestA are lost.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Setup_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestA', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestA', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestA', @LogIndex=4, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollbackSRDisabled. Row count in TestTableTRG2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestA', @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollbackSRDisabled. Row count in TriggerLog%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestA', @ExpectedLogEntryCount=5
   
   -- Make sure that no log entries recorded during SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestB are lost.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Setup_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestB', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestB', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestB', @LogIndex=4, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollbackSRDisabled. Row count in TestTableTRG2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestB', @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollbackSRDisabled. Row count in TriggerLog%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestB', @ExpectedLogEntryCount=5                            
                                                                                                                                                                                                                
   -- Make sure that no log entries recorded during SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestC are lost.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestC', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Setup_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestC', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestC', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestC', @LogIndex=4, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollbackSRDisabled. Row count in TestTableTRG2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestC', @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_Trigger_Setup_Multi_TranRollbackSRDisabled. Row count in TriggerLog%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestC', @ExpectedLogEntryCount=5                               
                                                                                                                                                                                                                
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where a suite has three tests. The teardown
-- causes a trigger that uses a transaction and does a ROLLBACK.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Trigger_Teardown_Multi_TranRollback
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
      
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @SuiteName           = 'Trigger_Teardown_Multi_TranRollback',
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Trigger_Teardown_Multi_TranRollback'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Trigger_Teardown_Multi_TranRollback#TestA,SQLTest_Trigger_Teardown_Multi_TranRollback#TestB,SQLTest_Trigger_Teardown_Multi_TranRollback#TestC', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Trigger_Teardown_Multi_TranRollback', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Trigger_Teardown_Multi_TranRollback', @SProcType='Teardown'

   -- Make sure that all the messages from all tests in this suite were recorded and not lost due to rolling back of a transaction
   SET @ExpectedLogMessage='ROLLBACK TRANSACTION detected in procedure ''InsertTestEntryTriggerTransactionRollback''. ' + 
               'All other TST messages logged during this test and previous to this error were lost. ' + 
               'Please disable the TST rollback if you expect the tested procedure to use ROLLBACK TRANSACTION. ' + 
               'To disable TST rollback create a stored procedure called TSTConfig in the database where you ' + 
               'have the test procedures. Inside TSTConfig call ' + 
               '<EXEC TST.Utils.SetConfiguration @ParameterName=''UseTSTRollback'', @ParameterValue=''0'' @Scope=''Test'', @ScopeValue=''_name_of_test_procedure_''>. ' + 
               'Warning: When you disable TST rollback, TST framework will not rollback the canges made by SETUP, test and TEARDOWN procedures. ' + 
               'See TST documentation for more details.'

   -- Note that some log entries made during SQLTest_Trigger_Teardown_Multi_TranRollback#TestA are lost due to the rollback made by the teardown procedure.
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollback#TestA', @LogIndex=1, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollback#TestA', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollback#TestA', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction was rolled back during the teardown procedure ''[TSTCheckTran].[dbo].[SQLTest_TEARDOWN_Trigger_Teardown_Multi_TranRollback]''.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollback#TestA', @ExpectedLogEntryCount=3
   
   -- Note that some log entries made during SQLTest_Trigger_Teardown_Multi_TranRollback#TestB are lost due to the rollback made by the teardown procedure.
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollback#TestB', @LogIndex=1, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollback#TestB', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollback#TestB', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction was rolled back during the teardown procedure ''[TSTCheckTran].[dbo].[SQLTest_TEARDOWN_Trigger_Teardown_Multi_TranRollback]''.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollback#TestB', @ExpectedLogEntryCount=3
   
   -- Note that some log entries made during SQLTest_Trigger_Teardown_Multi_TranRollback#TestA are lost due to the rollback made by the teardown procedure.
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollback#TestC', @LogIndex=1, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollback#TestC', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage=@ExpectedLogMessage
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollback#TestC', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction was rolled back during the teardown procedure ''[TSTCheckTran].[dbo].[SQLTest_TEARDOWN_Trigger_Teardown_Multi_TranRollback]''.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollback#TestC', @ExpectedLogEntryCount=3
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where a suite has three tests. The teardown
-- causes a trigger that uses a transaction and does a ROLLBACK.
-- The TST Rollback is disabled.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Transaction#Trigger_Teardown_Multi_TranRollbackSRDisabled
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @ExpectedLogMessage   nvarchar(4000)
      
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTran'    ,
      @SuiteName           = 'Trigger_Teardown_Multi_TranRollbackSRDisabled',
      @ResultsFormat       = 'None'                     ,
      @CleanTemporaryData  = 0                          ,
      @TestSessionId       = @TestSessionId OUT         ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Trigger_Teardown_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestA,SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestB,SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestC', @SProcType='Test'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_SETUP_Trigger_Teardown_Multi_TranRollbackSRDisabled', @SProcType='Setup'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_TEARDOWN_Trigger_Teardown_Multi_TranRollbackSRDisabled', @SProcType='Teardown'

   -- Make sure that no log entries recorded during SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestA are lost.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Teardown_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestA', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestA'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestA', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Teardown_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestA', @LogIndex=4, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestA', @ExpectedLogEntryCount=4
   
   -- Make sure that no log entries recorded during SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestB are lost.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Teardown_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestB', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestB'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestB', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Teardown_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestB', @LogIndex=4, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestB', @ExpectedLogEntryCount=4
   
   -- Make sure that no log entries recorded during SQLTest_Trigger_Setup_Multi_TranRollbackSRDisabled#TestC are lost.
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestC', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Trigger_Teardown_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestC', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestC'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestC', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Trigger_Teardown_Multi_TranRollbackSRDisabled'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestC', @LogIndex=4, @ExpectedLogType='E', @ExpectedLogMessage='%Error: 3609,%InsertTestEntryTriggerTransactionRollback%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Trigger_Teardown_Multi_TranRollbackSRDisabled#TestC', @ExpectedLogEntryCount=4
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- END TRANSACTION related features.
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- START error handling.
-- Test scenarios around invalid parameters sent to runners APIs: TST.dbo.RunXXX.
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- =======================================================================
-- Testing the case where the RunAll is called with an unknown database
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ErrorHandling#Test_RunAllUnknownDb
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunAll
      @TestDatabaseName    = 'SQLTest_UnknownDB'      ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOneSystemError @TestSessionId=@TestSessionId, @ExpectedErrorMessage='Database ''SQLTest_UnknownDB'' not found.'
   EXEC dbo.ValidateNoSuitesTestsOrTestLog @TestSessionId=@TestSessionId

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where the RunAll is called and no tests are detected.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ErrorHandling#Test_RunAllNoTests
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunAll
      @TestDatabaseName    = 'TSTCheckNoTests'      ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOneSystemError @TestSessionId=@TestSessionId, @ExpectedErrorMessage='No test procedure was detected for the given search criteria in database ''TSTCheckNoTests''.'
   EXEC dbo.ValidateNoSuitesTestsOrTestLog @TestSessionId=@TestSessionId

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where the RunSuite is called with an unknown database
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ErrorHandling#Test_RunSuiteUnknownDb
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'SQLTest_UnknownDB'   ,
      @SuiteName           = 'S1'                  ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOneSystemError @TestSessionId=@TestSessionId, @ExpectedErrorMessage='Database ''SQLTest_UnknownDB'' not found.'
   EXEC dbo.ValidateNoSuitesTestsOrTestLog @TestSessionId=@TestSessionId

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where the RunSuite is called with an unknown suite
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ErrorHandling#Test_RunSuiteUnknownSuite
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheck'  ,
      @SuiteName           = 'Suite_Unknown'       ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOneSystemError @TestSessionId=@TestSessionId, @ExpectedErrorMessage='Suite ''Suite_Unknown'' not found in database ''TSTCheck''.'
   EXEC dbo.ValidateNoSuitesTestsOrTestLog @TestSessionId=@TestSessionId

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Testing the case where SQL Server raises an run-time error.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ErrorHandling#Test_RunTimeError
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'  ,
      @TestName            = 'SQLTest_Test_RunTimeError',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateNoSystemErrors                          @TestSessionId=@TestSessionId
   EXEC dbo.ValidateTestButNoSuiteSetupTeardownRecorded     @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test_RunTimeError'

   -- Make sure that all the messages from all tests were recorded and not lost due to rolling back of a transaction
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_RunTimeError', @LogIndex=1, @ExpectedLogType='E', @ExpectedLogMessage='An error occured during the execution of the test procedure ''^[TSTCheck^].^[dbo^].^[SQLTest_Test_RunTimeError^]''. Error: 245%', @EscapeCharacter = '^'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_RunTimeError', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='The transaction is in an uncommitable state after the test procedure ''[TSTCheck].[dbo].[SQLTest_Test_RunTimeError]'' has failed. A rollback was forced. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_RunTimeError', @ExpectedLogEntryCount=2

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO


-- =======================================================================
-- Testing the case where the test does not call any Assert, Pass or Fail
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ErrorHandling#Test_NoAssert
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheck'  ,
      @TestName            = 'SQLTest_Test_NoAssert',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateNoSystemErrors                          @TestSessionId=@TestSessionId
   EXEC dbo.ValidateTestButNoSuiteSetupTeardownRecorded     @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test_NoAssert'

   -- Make sure that all the messages from all tests were recorded and not lost due to rolling back of a transaction
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_NoAssert', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Test_NoAssert'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_NoAssert', @LogIndex=2, @ExpectedLogType='F', @ExpectedLogMessage='No Assert, Fail, Pass or Ignore was invoked by this test. You must call at least one TST API that performs a validation, records a failure, records a pass or ignores the test (Assert..., Pass, Ignore, Fail, etc.)'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test_NoAssert', @ExpectedLogEntryCount=2

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- END error handling.
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- START testing table comparison API
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

/*
-- =======================================================================
-- Testing TST.Utils.DropTestTables
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_DirectCall_DropTestTables
AS
BEGIN

   DECLARE @ExpectedResultSysId  int
   DECLARE @ActualResultSysId    int


   IF (object_id('tempdb..#ActualResult') IS NOT NULL) DROP TABLE #ActualResult
   IF (object_id('tempdb..#ExpectedResult') IS NOT NULL) DROP TABLE #ExpectedResult

   -- called when #ActualResult and #ExpectedResult are not defined should not raise any exception
   EXEC TST.Utils.DropTestTables
   
   CREATE TABLE #ActualResult (Test int)
   CREATE TABLE #ExpectedResult (Test int)

   SET @ActualResultSysId = object_id('tempdb..#ActualResult')
   EXEC TST.Assert.IsNotNull 'ActualResultSysId after DropTestTables', @ActualResultSysId
   
   SET @ExpectedResultSysId = object_id('tempdb..#ExpectedResult') 
   EXEC TST.Assert.IsNotNull 'ExpectedResultSysId after DropTestTables', @ExpectedResultSysId
   
   EXEC TST.Utils.DropTestTables
   
   SET @ActualResultSysId = object_id('tempdb..#ActualResult')
   EXEC TST.Assert.IsNull 'ActualResultSysId after DropTestTables', @ActualResultSysId
   
   SET @ExpectedResultSysId = object_id('tempdb..#ExpectedResult') 
   EXEC TST.Assert.IsNull 'ExpectedResultSysId after DropTestTables', @ExpectedResultSysId
   
END
GO
*/

-- =======================================================================
-- Testing TST.Utils.DeleteTestTables
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#DirectCall_DeleteTestTables
AS
BEGIN

   DECLARE @RowCount int 

   CREATE TABLE #ActualResult (Test int)
   CREATE TABLE #ExpectedResult (Test int)
   
   INSERT INTO #ActualResult     SELECT 1
   INSERT INTO #ExpectedResult   SELECT 1
   
   EXEC TST.Utils.DeleteTestTables
   
   SELECT @RowCount = COUNT(*) FROM #ActualResult 
   EXEC TST.Assert.Equals 'Row count in #ActualResult', 0, @RowCount 
   
   SELECT @RowCount = COUNT(*) FROM #ExpectedResult 
   EXEC TST.Assert.Equals 'Row count in #ExpectedResult', 0, @RowCount 

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different sizes
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesDifferentSizes
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesDifferentSizes' ,
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesDifferentSizes', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessage='Assert.TableEquals failed. [Test Assert in SQLTest_TablesDifferentSizes] Expected row count=1. Actual row count=0'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO


-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different schema. Case: column in #ActualResult but not in #ExpectedResult
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesDifferentSchemaCols1
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesDifferentSchemaCols1',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesDifferentSchemaCols1', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_TablesDifferentSchemaCols1] #ExpectedResult and #ActualResult do not have the same schema. Column ''C2'' in #ActualResult but not in #ExpectedResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different schema. Case: column in #ExpectedResult but not in #ActualResult
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesDifferentSchemaCols2
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesDifferentSchemaCols2',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesDifferentSchemaCols2', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_TablesDifferentSchemaCols2] #ExpectedResult and #ActualResult do not have the same schema. Column ''C2'' in #ExpectedResult but not in #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different schema. Case: #ExpectedResult has one column: C1, 
-- #ActualResult has one column: C2 
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesDifferentSchemaCols3
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesDifferentSchemaCols3',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesDifferentSchemaCols3', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_TablesDifferentSchemaCols3] #ExpectedResult and #ActualResult do not have the same schema. Column ''C1'' in #ExpectedResult but not in #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO


-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different schema. Case: #ExpectedResult has one column: C1 of type int, 
-- #ActualResult has one column: C1 of type varchar
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesDifferentSchemaColTypes1
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesDifferentSchemaColTypes1',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesDifferentSchemaColTypes1', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_TablesDifferentSchemaColTypes1] #ExpectedResult and #ActualResult do not have the same schema. Column #ExpectedResult.C1 has type int. #ActualResult.C1 has type varchar'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different schema. Case: 
-- #ExpectedResult has one column:  C1 of type varchar(10), 
-- #ActualResult has one column:    C1 of type varchar(11)
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesDifferentSchemaColTypes2
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesDifferentSchemaColTypes2',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesDifferentSchemaColTypes2', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_TablesDifferentSchemaColTypes2] #ExpectedResult and #ActualResult do not have the same schema. Column #ExpectedResult.C1 has length 10. #ActualResult.C1 has length 11'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different schema. The difference is in collation of one column.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesDifferentSchemaCollation
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesDifferentSchemaCollation',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesDifferentSchemaCollation', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_TablesDifferentSchemaCollation] #ExpectedResult and #ActualResult do not have the same schema. Column #ExpectedResult.C1 has collation SQL_Latin1_General_CP1_CS_AS. #ActualResult.C1 has collation SQL_Latin1_General_CP1_CI_AS'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables 
-- have a column of type text
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesColTypeText
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesColTypeText'    ,
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesColTypeText', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_TablesColTypeText] Column C1 has a type (''text'') that cannot be processed by Assert.TableEquals. To ignore this column use the @IgnoredColumns parameter of Assert.TableEquals.'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables 
-- have a column of type ntext
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesColTypeNText
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesColTypeNText'   ,
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesColTypeNText', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_TablesColTypeNText] Column C1 has a type (''ntext'') that cannot be processed by Assert.TableEquals. To ignore this column use the @IgnoredColumns parameter of Assert.TableEquals.'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables 
-- have a column of type image
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesColTypeImage
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesColTypeImage'   ,
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesColTypeImage', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_TablesColTypeImage] Column C1 has a type (''image'') that cannot be processed by Assert.TableEquals. To ignore this column use the @IgnoredColumns parameter of Assert.TableEquals.'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables 
-- have a column of type Timestamp
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesColTypeTimestamp
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesColTypeTimestamp',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesColTypeTimestamp', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_TablesColTypeTimestamp] Column C1 has a type (''timestamp'') that cannot be processed by Assert.TableEquals. To ignore this column use the @IgnoredColumns parameter of Assert.TableEquals.'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables 
-- do not have a primary key
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesNoPrimaryKey
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesNoPrimaryKey'   ,
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesNoPrimaryKey', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_TablesNoPrimaryKey] #ExpectedResult and #ActualResult must have a primary key defined'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables 
-- do not have the same primary key.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesDifferentPrimaryKey
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesDifferentPrimaryKey',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesDifferentPrimaryKey', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_TablesDifferentPrimaryKey] The primary keys in #ExpectedResult and #ActualResult are not the same'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables 
-- do not have the same primary key. They both have the PK defined on the same 
-- columns but the columns in PK are in different order
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesPrimaryKeyColsDifferentOrder
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesPrimaryKeyColsDifferentOrder',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesPrimaryKeyColsDifferentOrder', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_TablesPrimaryKeyColsDifferentOrder] The primary keys in #ExpectedResult and #ActualResult are not the same'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have the 
-- same schema and data. They both have the PK defined on one column.
-- The columns have spaces in their names.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareSameDataColumnNamesWithBlanks
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareColumnNamesWithBlanks',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareColumnNamesWithBlanks', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in SQLTest_TablesCompareColumnNamesWithBlanks] 2 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have the 
-- same schema and data. They both have the PK defined on one column.
-- The columns have spaces in their names. Some of the columns are ignored.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareSameDataColumnNamesWithBlanksAndIgnoredColumns
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareColumnNamesWithBlanksAndIgnoredColumns',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareColumnNamesWithBlanksAndIgnoredColumns', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in SQLTest_TablesCompareColumnNamesWithBlanksAndIgnoredColumns] 2 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have the 
-- same schema and data. They both have the PK defined on one column.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareSameDataPK1
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareSameDataPK1',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareSameDataPK1', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in SQLTest_TablesCompareSameDataPK1 ĂÎÂȘȚăîâșț] 2 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals when ContextMessage is NULL.
-- The two temp tables have the same schema and data. They both have a PK 
-- defined on one column.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareSameDataNullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareSameDataNullContext',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareSameDataNullContext', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [] 2 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have the 
-- same schema and data. However #ExpectedResult and #ActualResult tables
-- have the same columns defined in a different order.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareSameDataReversedColumns
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareSameDataReversedColumns',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareSameDataReversedColumns', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in SQLTest_TablesCompareSameDataReversedColumns] 2 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have the 
-- same schema and data. They both have the PK defined on three columns.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareSameDataPK3
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareSameDataPK3',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareSameDataPK3', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in SQLTest_TablesCompareSameDataPK3] 8 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different different data. 
-- Case: One PK column. the PK matches, data will have a difference. See 
-- SQLTest_TablesCompareDifferentDataPK1_Case1 in SetTSTCheckTable.sql
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareDifferentDataPK1_Case1
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareDifferentDataPK1_Case1',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareDifferentDataPK1_Case1', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='Assert.TableEquals failed. ^[Test Assert in SQLTest_TablesCompareDifferentDataPK1_Case1^] #ExpectedResult and #ActualResult do not have the same data. Expected/Actual: %',
         @EscapeCharacter = '^'
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different different data. 
-- Case: One PK column. the data is the same but for rows having different 
-- PK keys. See 
-- SQLTest_TablesCompareDifferentDataPK1_Case2 in SetTSTCheckTable.sql
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareDifferentDataPK1_Case2
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareDifferentDataPK1_Case2',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareDifferentDataPK1_Case2', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='Assert.TableEquals failed. ^[Test Assert in SQLTest_TablesCompareDifferentDataPK1_Case2^] #ExpectedResult and #ActualResult do not have the same data. Expected/Actual: %',
         @EscapeCharacter = '^'
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different different data. 
-- Case: One PK column. The PK columns don't have the same values. See
-- SQLTest_TablesCompareDifferentDataPK1_Case3 in SetTSTCheckTable.sql
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareDifferentDataPK1_Case3
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareDifferentDataPK1_Case3',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareDifferentDataPK1_Case3', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='Assert.TableEquals failed. ^[Test Assert in SQLTest_TablesCompareDifferentDataPK1_Case3^] #ExpectedResult and #ActualResult do not have the same data. Expected/Actual: %',
         @EscapeCharacter = '^'
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different different data. 
-- Case: One PK column. See SQLTest_TablesCompareDifferentDataPK1_Case4 
-- in SetTSTCheckTable.sql
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareDifferentDataPK1_Case4
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareDifferentDataPK1_Case4',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareDifferentDataPK1_Case4', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='Assert.TableEquals failed. ^[Test Assert in SQLTest_TablesCompareDifferentDataPK1_Case4^] #ExpectedResult and #ActualResult do not have the same data. Expected/Actual: %',
         @EscapeCharacter = '^'
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different different data. 
-- Case: Three PK columns. the PK matches, data will have a difference. See 
-- SQLTest_TablesCompareDifferentDataPK3_Case1 in SetTSTCheckTable.sql
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareDifferentDataPK3_Case1
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareDifferentDataPK3_Case1',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareDifferentDataPK3_Case1', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='Assert.TableEquals failed. ^[Test Assert in SQLTest_TablesCompareDifferentDataPK3_Case1^] #ExpectedResult and #ActualResult do not have the same data. Expected/Actual: %',
         @EscapeCharacter = '^'
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO


-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different different data. 
-- Case: Three PK columns. the data is the same but for rows having different 
-- PK keys. See 
-- SQLTest_TablesCompareDifferentDataPK3_Case2 in SetTSTCheckTable.sql
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareDifferentDataPK3_Case2
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareDifferentDataPK3_Case2',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareDifferentDataPK3_Case2', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='Assert.TableEquals failed. ^[Test Assert in SQLTest_TablesCompareDifferentDataPK3_Case2^] #ExpectedResult and #ActualResult do not have the same data. Expected/Actual: %',
         @EscapeCharacter = '^'
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different different data. 
-- Case: Three PK columns. The PK columns don't have the same values. See
-- SQLTest_TablesCompareDifferentDataPK3_Case3 in SetTSTCheckTable.sql
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareDifferentDataPK3_Case3
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareDifferentDataPK3_Case3',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareDifferentDataPK3_Case3', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='Assert.TableEquals failed. ^[Test Assert in SQLTest_TablesCompareDifferentDataPK3_Case3^] #ExpectedResult and #ActualResult do not have the same data. Expected/Actual: %',
         @EscapeCharacter = '^'
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- different different data. 
-- Case: Three PK columns. See SQLTest_TablesCompareDifferentDataPK3_Case4
-- in SetTSTCheckTable.sql
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareDifferentDataPK3_Case4
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareDifferentDataPK3_Case4',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareDifferentDataPK3_Case4', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='Assert.TableEquals failed. ^[Test Assert in SQLTest_TablesCompareDifferentDataPK3_Case4^] #ExpectedResult and #ActualResult do not have the same data. Expected/Actual: %',
         @EscapeCharacter = '^'
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have the 
-- same schema and data. They both have two columns with a specified 
-- collation. The two columns have the same collation.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareSameDataOneCollation
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareSameDataOneCollation',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareSameDataOneCollation', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in SQLTest_TablesCompareSameDataOneCollation] 3 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have the 
-- same schema and data. They both have two columns with a specified 
-- collation. The two columns have a different collation.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareSameDataVariousCollation
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareSameDataVariousCollation',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareSameDataVariousCollation', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in SQLTest_TablesCompareSameDataVariousCollation] 3 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have the 
-- same schema but different data. They both have two columns with a specified 
-- collation. The two columns have a different collation.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareDifferentDataVariousCollation
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TablesCompareDifferentDataVariousCollation',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TablesCompareDifferentDataVariousCollation', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='Assert.TableEquals failed. ^[Test Assert in SQLTest_TablesCompareDifferentDataVariousCollation^] #ExpectedResult and #ActualResult do not have the same data. Expected/Actual: %',
         @EscapeCharacter = '^'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables 
-- #ExpectedResult and #ActualResult have one PK column and one 
-- data column. The data in the temp tables is the same. 
-- =======================================================================
CREATE PROCEDURE dbo.TablesCompareSameData
   @TestMethodPrefix    nvarchar(128),    -- The prefix of the test method that is feed into TST
   @RowCount            int = 4           -- The number of rows compared by the test sproc
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @TestName             sysname
   DECLARE @ExpectedLogMessage   nvarchar(4000)   
   DECLARE @ContextMessage       nvarchar(100)   
   
   SET @TestName = 'SQLTest_TablesCompareSameData_' + @TestMethodPrefix
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'          ,
      @TestName            = @TestName                ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   SET @ContextMessage = 'The test session must have passed for ' + @TestMethodPrefix
   EXEC TST.Assert.Equals @ContextMessage , 1, @TestSessionPassed

   SET @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in ' + @TestName + '] ' + CAST(@RowCount as varchar) + ' row(s) compared between #ExpectedResult and #ActualResult'

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName=@TestName, 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage=@ExpectedLogMessage

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables 
-- #ExpectedResult and #ActualResult have one PK column and one 
-- data column. The data in the temp tables is different. 
-- =======================================================================
CREATE PROCEDURE dbo.TablesCompareDifferentData
   @TestMethodPrefix    nvarchar(128),    -- The prefixofthe test method that is feed into TST
   @DataDifString       nvarchar(4000)    -- Part ofthe expected error string that 
                                          -- should be produced by Assert.TableEquals
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @TestName             sysname
   DECLARE @ExpectedLogMessage   nvarchar(4000)   
   DECLARE @ContextMessage       nvarchar(100)   
   
   SET @TestName = 'SQLTest_TablesCompareDifferentData_' + @TestMethodPrefix

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'          ,
      @TestName            = @TestName                ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   SET @ContextMessage = 'The test session must have failed for ' + @TestMethodPrefix
   EXEC TST.Assert.Equals @ContextMessage, 0, @TestSessionPassed

   SET @ExpectedLogMessage = 'Assert.TableEquals failed. [Test Assert in ' + @TestName + '] #ExpectedResult and #ActualResult do not have the same data. ' + 
      'Expected/Actual: ID1=(1/1) Col1=(' + @DataDifString + ') '

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName=@TestName, 
         @ExpectedEntryType='F', 
         @ExpectedLogMessage=@ExpectedLogMessage

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables 
-- #ExpectedResult and #ActualResult have one PK column and one 
-- data column. The data in the temp tables is the same. 
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareSameDataByType
AS
BEGIN

   EXEC dbo.TablesCompareSameData 'BigInt'
   EXEC dbo.TablesCompareSameData 'Int'
   EXEC dbo.TablesCompareSameData 'SmallInt'
   EXEC dbo.TablesCompareSameData 'TinyInt'
   EXEC dbo.TablesCompareSameData 'Money'
   EXEC dbo.TablesCompareSameData 'SmallMoney'
   EXEC dbo.TablesCompareSameData 'Bit', 3
   EXEC dbo.TablesCompareSameData 'Decimal', 6
   EXEC dbo.TablesCompareSameData 'Numeric', 6
   EXEC dbo.TablesCompareSameData 'Float', 7
   EXEC dbo.TablesCompareSameData 'Real', 5
   EXEC dbo.TablesCompareSameData 'DateTime', 5
   EXEC dbo.TablesCompareSameData 'SmallDateTime', 4
   EXEC dbo.TablesCompareSameData 'Char', 4
   EXEC dbo.TablesCompareSameData 'NChar', 6
   EXEC dbo.TablesCompareSameData 'Char100', 4
   EXEC dbo.TablesCompareSameData 'NChar100', 4
   EXEC dbo.TablesCompareSameData 'VarChar', 4
   EXEC dbo.TablesCompareSameData 'NVarChar', 4
   EXEC dbo.TablesCompareSameData 'VarChar100', 4
   EXEC dbo.TablesCompareSameData 'NVarChar100', 4
   EXEC dbo.TablesCompareSameData 'VarCharMax', 4
   EXEC dbo.TablesCompareSameData 'NVarCharMax', 4
   EXEC dbo.TablesCompareSameData 'Binary', 4
   EXEC dbo.TablesCompareSameData 'Binary10', 4
   EXEC dbo.TablesCompareSameData 'VarBinary', 4
   EXEC dbo.TablesCompareSameData 'VarBinary10', 4
   EXEC dbo.TablesCompareSameData 'VarBinaryMax', 4
   EXEC dbo.TablesCompareSameData 'SQLVariant', 4
   EXEC dbo.TablesCompareSameData 'Uniqueidentifier', 3

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables 
-- #ExpectedResult and #ActualResult have one PK column and one 
-- data column. The data in the temp tables is different. 
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TablesCompareDifferentDataByType
AS
BEGIN

   EXEC dbo.TablesCompareDifferentData 'BigInt'          , '-9223372036854775808/9223372036854775807'
   EXEC dbo.TablesCompareDifferentData 'Int'             , '-2147483648/2147483647'
   EXEC dbo.TablesCompareDifferentData 'SmallInt'        , '-32768/32767'
   EXEC dbo.TablesCompareDifferentData 'TinyInt'         , '254/255'
   EXEC dbo.TablesCompareDifferentData 'Money'           , '-922337203685477.5808/922337203685477.5807'
   EXEC dbo.TablesCompareDifferentData 'SmallMoney'      , '-214748.3648/214748.3647'
   EXEC dbo.TablesCompareDifferentData 'Bit'             , '0/1'
   EXEC dbo.TablesCompareDifferentData 'Decimal'         , '2345678901234567890123456789.0123456788/2345678901234567890123456789.0123456789'
   EXEC dbo.TablesCompareDifferentData 'Numeric'         , '234567890123456789.01234567890123456788/234567890123456789.01234567890123456789'
   EXEC dbo.TablesCompareDifferentData 'Float'           , '1.234567890123457e+000/1.234567890123456e+000'
   EXEC dbo.TablesCompareDifferentData 'Real'            , '1.2345679e+000/1.2345678e+000'
   EXEC dbo.TablesCompareDifferentData 'DateTime'        , '2000-01-01 23:59:59.010/2000-01-01 23:59:59.000'
   EXEC dbo.TablesCompareDifferentData 'SmallDateTime'   , '2000-01-01 23:58:00/2000-01-01 23:59:00'
   EXEC dbo.TablesCompareDifferentData 'Char'            , 'a/A'
   EXEC dbo.TablesCompareDifferentData 'NChar'           , N'ț/t'
   EXEC dbo.TablesCompareDifferentData 'Char100'         , '123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789A/123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789a'
   EXEC dbo.TablesCompareDifferentData 'NChar100'        , N'123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789A/123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789a'
   EXEC dbo.TablesCompareDifferentData 'VarChar'         , 'A/a'
   EXEC dbo.TablesCompareDifferentData 'NVarChar'        , N'ĂÎÂȘȚăîâșț/ĂÎÂȘȚăîâșt'
   EXEC dbo.TablesCompareDifferentData 'VarChar100'      , '123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789A/123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789a'
   EXEC dbo.TablesCompareDifferentData 'NVarChar100'     , N'123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789A/123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789a'
   EXEC dbo.TablesCompareDifferentData 'VarCharMax'      , '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789A/1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789a'
   EXEC dbo.TablesCompareDifferentData 'NVarCharMax'     , N'1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789A/1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789a'
   EXEC dbo.TablesCompareDifferentData 'Binary'          , '...binary value.../...binary value...'
   EXEC dbo.TablesCompareDifferentData 'Binary10'        , '...binary value.../...binary value...'
   EXEC dbo.TablesCompareDifferentData 'VarBinary'       , '...binary value.../...binary value...'
   EXEC dbo.TablesCompareDifferentData 'VarBinary10'     , '...binary value.../...binary value...'
   EXEC dbo.TablesCompareDifferentData 'VarBinaryMax'    , '...binary value.../...binary value...'
   EXEC dbo.TablesCompareDifferentData 'SQLVariant'      , '0/1'
   EXEC dbo.TablesCompareDifferentData 'Uniqueidentifier', '6A88E546-117B-400F-B69C-C355D827D68C/6A88E546-117B-400F-B69C-C355D827D68D'


END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case where the @IgnoredColumns 
-- parameter has the same column specified twice.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#IgnoredColumnsHaveTheSameName
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_IgnoredColumnsHaveTheSameName',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IgnoredColumnsHaveTheSameName', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_IgnoredColumnsHaveTheSameName] Column ''C1'' is specified more than once in the list of ignored columns.'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case where the @IgnoredColumns 
-- parameter has specifies a column that does not exist in any of 
-- #ActualResult or #ExpectedResult.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#IgnoredColumnIsUnknown
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_IgnoredColumnsIsUnknown',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IgnoredColumnsIsUnknown', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_IgnoredColumnsIsUnknown] Column ''CX'' from the list of ignored columns does not exist in any of #ActualResult or #ExpectedResult.'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when an ignored column 
-- has different types in the two tables. 
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#IgnoredColumnsHaveDifferentTypes
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_IgnoredColumnsHaveDifferentTypes',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IgnoredColumnsHaveDifferentTypes', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_IgnoredColumnsHaveDifferentTypes] #ExpectedResult and #ActualResult do not have the same schema. Column #ExpectedResult.C2 has type int. #ActualResult.C2 has type varchar'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when an ignored column 
-- has different lengths in the two tables. 
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#IgnoredColumnsHaveDifferentLengths
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_IgnoredColumnsHaveDifferentLengths',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IgnoredColumnsHaveDifferentLengths', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_IgnoredColumnsHaveDifferentLengths] #ExpectedResult and #ActualResult do not have the same schema. Column #ExpectedResult.C2 has length 10. #ActualResult.C2 has length 11'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when an ignored column 
-- has different collations in the two tables. 
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#IgnoredColumnsHaveDifferentCollations
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_IgnoredColumnsHaveDifferentCollations',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IgnoredColumnsHaveDifferentCollations', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_IgnoredColumnsHaveDifferentCollations] #ExpectedResult and #ActualResult do not have the same schema. Column #ExpectedResult.C2 has collation SQL_Latin1_General_CP1_CS_AS. #ActualResult.C2 has collation SQL_Latin1_General_CP1_CI_AS'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when an ignored column 
-- is in the primary key. 
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#IgnoredColumnIsInPrimaryKey
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_IgnoredColumnIsInPrimaryKey',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IgnoredColumnIsInPrimaryKey', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessage='Invalid call to Assert.TableEquals. [Test Assert in SQLTest_IgnoredColumnIsInPrimaryKey] Column ''ID2'' that is specified in the list of ignored columns cannot be ignored because is part of the primary key in #ActualResult and #ExpectedResult.'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- each a column of an invalid type but that column is ignored. 
-- In the rest of the columns the data is the same.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#IgnoredColumnsHaveInvalidType_SameDataInRegularColumns
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_IgnoredColumnHasInvalidType_SameDataInRegularColumns',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IgnoredColumnHasInvalidType_SameDataInRegularColumns', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in SQLTest_IgnoredColumnHasInvalidType_SameDataInRegularColumns] 2 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO


-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- each a column of an invalid type but that column is ignored. 
-- There are also differences in the data stored in the regular columns.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#IgnoredColumnHasInvalidType_DiffDataInRegularColumns
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_IgnoredColumnHasInvalidType_DiffDataInRegularColumns',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IgnoredColumnHasInvalidType_DiffDataInRegularColumns', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='Assert.TableEquals failed. ^[Test Assert in SQLTest_IgnoredColumnHasInvalidType_DiffDataInRegularColumns^] #ExpectedResult and #ActualResult do not have the same data. Expected/Actual: %',
         @EscapeCharacter = '^'
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when #ExpectedResult has a 
-- column that is ignored. That column is absent from #ActualResult.
-- In the rest of the columns the data is the same.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#IgnoredColumnOnlyInExpectedResult_SameDataInRegularColumns
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_IgnoredColumnOnlyInExpectedResult_SameDataInRegularColumns',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IgnoredColumnOnlyInExpectedResult_SameDataInRegularColumns', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in SQLTest_IgnoredColumnOnlyInExpectedResult_SameDataInRegularColumns] 2 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when #ExpectedResult has two 
-- columns that are ignored. Those columns are absent from #ActualResult.
-- In the rest of the columns the data is the same.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#IgnoredColumnOnlyInExpectedResult_SameDataInRegularColumns_2
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_IgnoredColumnOnlyInExpectedResult_SameDataInRegularColumns_2',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IgnoredColumnOnlyInExpectedResult_SameDataInRegularColumns_2', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in SQLTest_IgnoredColumnOnlyInExpectedResult_SameDataInRegularColumns_2] 2 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when #ActualResult has a 
-- column that is ignored. That column is absent from #ExpectedResult.
-- In the rest of the columns the data is the same.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#IgnoredColumnOnlyInActualResult_SameDataInRegularColumns
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_IgnoredColumnOnlyInActualResult_SameDataInRegularColumns',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IgnoredColumnOnlyInActualResult_SameDataInRegularColumns', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in SQLTest_IgnoredColumnOnlyInActualResult_SameDataInRegularColumns] 2 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when #ActualResult has two 
-- columns that are ignored. Those columns are absent from #ExpectedResult.
-- In the rest of the columns the data is the same.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#IgnoredColumnOnlyInActualResult_SameDataInRegularColumns_2
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_IgnoredColumnOnlyInActualResult_SameDataInRegularColumns_2',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IgnoredColumnOnlyInActualResult_SameDataInRegularColumns_2', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in SQLTest_IgnoredColumnOnlyInActualResult_SameDataInRegularColumns_2] 2 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when data in the ignored 
-- column is different. Data in the rest of the columns is the same.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#SameDataExceptForIgnoredColumn
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_SameDataExceptForIgnoredColumn',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_SameDataExceptForIgnoredColumn', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in SQLTest_SameDataExceptForIgnoredColumn] 2 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing Assert.TableEquals for the case when data in the ignored 
-- columns is different. Data in the rest of the columns is the same.
-- There are two ignored columns.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#SameDataExceptForIgnoredColumn_2
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_SameDataExceptForIgnoredColumn_2',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_SameDataExceptForIgnoredColumn_2', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Assert.TableEquals passed. [Test Assert in SQLTest_SameDataExceptForIgnoredColumn_2] 2 row(s) compared between #ExpectedResult and #ActualResult'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO


-- =======================================================================
-- Testing Assert.TableEquals for the case when the temp tables have 
-- each a column of an invalid type but that column is ignored. 
-- There are also differences in the data stored in the regular columns.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TableCompAPI#TwoIgnoredColumns_DifferentDataInRegularColumns
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTable'                ,
      @TestName            = 'SQLTest_TwoIgnoredColumns_DifferentDataInRegularColumns',
      @ResultsFormat       = 'None'                         ,
      @CleanTemporaryData  = 0                              ,
      @TestSessionId       = @TestSessionId OUT             ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_TwoIgnoredColumns_DifferentDataInRegularColumns', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='Assert.TableEquals failed. ^[Test Assert in SQLTest_TwoIgnoredColumns_DifferentDataInRegularColumns^] #ExpectedResult and #ActualResult do not have the same data. Expected/Actual: %',
         @EscapeCharacter = '^'
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- END testing table comparison API
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- START testing the expected error 
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


-- =======================================================================
-- Testing the case where the tested stored procedure raises an 
-- unexpeced error.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ExpectedErrors#UnexpectedError
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckError'          ,
      @TestName            = 'SQLTest_UnexpectedError',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_UnexpectedError', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='An error occured during the execution of the test procedure %SQLTest_UnexpectedError%'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where the tested stored procedure 
-- does not raise an expeced error.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ExpectedErrors#NotRaised
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckError'       ,
      @TestName            = 'SQLTest_ExpectedErrorNotRaised',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateNoSystemErrors                          @TestSessionId=@TestSessionId
   EXEC dbo.ValidateTestButNoSuiteSetupTeardownRecorded     @TestSessionId=@TestSessionId, @SProcName='SQLTest_ExpectedErrorNotRaised'

   -- Make sure that all the messages from all tests were recorded and not lost due to rolling back of a transaction
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_ExpectedErrorNotRaised', @LogIndex=1, @ExpectedLogType='P', @ExpectedLogMessage='Test Pass in SQLTest_ExpectedErrorNotRaised'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_ExpectedErrorNotRaised', @LogIndex=2, @ExpectedLogType='F', @ExpectedLogMessage='Test ^[TSTCheckError^].^[dbo^].^[SQLTest_ExpectedErrorNotRaised^] failed. ^[This is supposed to raise an error^] Expected error was not raised:%', @EscapeCharacter='^'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_ExpectedErrorNotRaised', @ExpectedLogEntryCount=2

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where the tested stored procedure raises an 
-- expected error and the ExpectedErrorMessage is specified.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ExpectedErrors#ByMessage
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckError'          ,
      @TestName            = 'SQLTest_ExpectedErrorMessage',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_ExpectedErrorMessage', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Test [TSTCheckError].[dbo].[SQLTest_ExpectedErrorMessage] passed. [RaiseAnError is supposed to raise an error] Expected error was raised: Error number: N/A Procedure: ''N/A'' Message: Test error'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where the tested stored procedure raises an 
-- expected error and the ExpectedErrorProcedure is specified.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ExpectedErrors#ByProcedure
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckError'          ,
      @TestName            = 'SQLTest_ExpectedErrorProcedure',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_ExpectedErrorProcedure', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Test [TSTCheckError].[dbo].[SQLTest_ExpectedErrorProcedure] passed. [RaiseAnError is supposed to raise an error] Expected error was raised: Error number: N/A Procedure: ''RaiseAnError'' Message: N/A'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where the tested stored procedure raises an 
-- expected error and the ExpectedErrorNumber is specified.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ExpectedErrors#ByNumber
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckError'          ,
      @TestName            = 'SQLTest_ExpectedErrorNumber',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_ExpectedErrorNumber', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Test [TSTCheckError].[dbo].[SQLTest_ExpectedErrorNumber] passed. [RaiseAnError is supposed to raise an error] Expected error was raised: Error number: 50000 Procedure: ''N/A'' Message: N/A'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where the tested stored procedure raises an 
-- expected error and the ExpectedErrorMessage, ExpectedErrorProcedure and
-- ExpectedErrorNumber are specified.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ExpectedErrors#ByMessageProcedureNumber
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckError'          ,
      @TestName            = 'SQLTest_ExpectedError',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_ExpectedError', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Test [TSTCheckError].[dbo].[SQLTest_ExpectedError] passed. [RaiseAnError is supposed to raise an error] Expected error was raised: Error number: 50000 Procedure: ''RaiseAnError'' Message: Test error'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO


-- =======================================================================
-- Testing the case where the tested stored procedure raises an 
-- expected error and @ExpectedErrorContextMessage is NULL
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ExpectedErrors#NullContext
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckError'          ,
      @TestName            = 'SQLTest_ExpectedErrorNullContext',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_ExpectedErrorNullContext', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessage='Test [TSTCheckError].[dbo].[SQLTest_ExpectedErrorNullContext] passed. [] Expected error was raised: Error number: 50000 Procedure: ''RaiseAnError'' Message: Test error'

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where the setup stored procedure calls
-- RegisterExpectedError (which is an error)
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ExpectedErrors#SetupCallsExpectedError
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckError'          ,
      @TestName            = 'SQLTest_SetupCallsExpectedError#Test',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='SetupCallsExpectedError'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SetupCallsExpectedError#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_SetupCallsExpectedError', @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_SetupCallsExpectedError', @SProcType='Teardown'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SetupCallsExpectedError#Test', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_SetupCallsExpectedError'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SetupCallsExpectedError#Test', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='A setup procedure cannot invoke RegisterExpectedError. RegisterExpectedError can only be invoked by a test procedure before the error is raised.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SetupCallsExpectedError#Test', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_SetupCallsExpectedError'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SetupCallsExpectedError#Test', @ExpectedLogEntryCount=3

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where the teardown stored procedure calls
-- RegisterExpectedError (which is an error)
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_ExpectedErrors#TeardownCallsExpectedError
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckError'          ,
      @TestName            = 'SQLTest_TeardownCallsExpectedError#Test',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='TeardownCallsExpectedError'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TeardownCallsExpectedError#Test', @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_TeardownCallsExpectedError', @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_TeardownCallsExpectedError', @SProcType='Teardown'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_TeardownCallsExpectedError#Test', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_TeardownCallsExpectedError'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_TeardownCallsExpectedError#Test', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TeardownCallsExpectedError#Test'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_TeardownCallsExpectedError#Test', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_TeardownCallsExpectedError'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_TeardownCallsExpectedError#Test', @LogIndex=4, @ExpectedLogType='E', @ExpectedLogMessage='A teardown procedure cannot invoke RegisterExpectedError. RegisterExpectedError can only be invoked by a test procedure before the error is raised.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_TeardownCallsExpectedError#Test', @ExpectedLogEntryCount=4

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- END testing the expected error 
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- START testing the test procedure in its own schema
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


-- =======================================================================
-- Testing the case where a suite and its tests are written in a schema 
-- other than dbo. Running one entire suite.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Schemas#SchemaForSuite
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckSchema'         ,
      @SuiteName           = 'Suite1'                 ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite1'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite1#Test1_A'   , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_Suite1'     , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_Suite1'  , @SProcType='Teardown'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_A', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is TestSchema1.SQLTest_SETUP_Suite1'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_A', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is TestSchema1.SQLTest_Suite1#Test1_A'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_A', @LogIndex=3, @ExpectedLogType='F', @ExpectedLogMessage='%Failing test in TestSchema1.SQLTest_Suite1#Test1_A%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_A', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is TestSchema1.SQLTest_TEARDOWN_Suite1'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_A', @ExpectedLogEntryCount=4

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_B', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is TestSchema1.SQLTest_SETUP_Suite1'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_B', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is TestSchema1.SQLTest_Suite1#Test1_B'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_B', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Passing test in TestSchema1.SQLTest_Suite1#Test1_B%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_B', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is TestSchema1.SQLTest_TEARDOWN_Suite1'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_B', @ExpectedLogEntryCount=4

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO


-- =======================================================================
-- Testing the case where a suite and its tests are written in a schema 
-- other than dbo. Running one test.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Schemas#SchemaForTestInSuite
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckSchema'         ,
      @TestName            = 'SQLTest_Suite1#Test1_A'   ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite1'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite1#Test1_A'   , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_Suite1'     , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_Suite1'  , @SProcType='Teardown'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_A', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is TestSchema1.SQLTest_SETUP_Suite1'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_A', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is TestSchema1.SQLTest_Suite1#Test1_A'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_A', @LogIndex=3, @ExpectedLogType='F', @ExpectedLogMessage='%Failing test in TestSchema1.SQLTest_Suite1#Test1_A%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_A', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is TestSchema1.SQLTest_TEARDOWN_Suite1'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#Test1_A', @ExpectedLogEntryCount=4

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where two suites in different schemas have the 
-- same name. The two suites have setup, teardown and tests.
-- Running the suite will trigger a system error.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Schemas#SuitesWithSameName
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @SuiteCount           int

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckSchema'      ,
      @SuiteName           = 'SuiteA'              ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession     @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOneSystemError  @TestSessionId=@TestSessionId, @ExpectedErrorMessage='The suite name ''SuiteA'' appears to be duplicated across different schemas in database ''TSTCheckSchema''.'

   SET @SuiteCount = NULL
   SELECT @SuiteCount = COUNT(*) FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId AND SuiteName = 'SuiteA'
   EXEC TST.Assert.Equals 'There must be 2 suites SuiteA', 2, @SuiteCount
   
   SET @SuiteCount = NULL
   SELECT @SuiteCount = COUNT(*) FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId AND SchemaName = 'TestSchema2' AND SuiteName = 'SuiteA'
   EXEC TST.Assert.Equals 'There must be 1 suite SuiteA in schema TestSchema2', 1, @SuiteCount
   
   SET @SuiteCount = NULL
   SELECT @SuiteCount = COUNT(*) FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId AND SchemaName = 'TestSchema3' AND SuiteName = 'SuiteA'
   EXEC TST.Assert.Equals 'There must be 1 suite SuiteA in schema TestSchema3', 1, @SuiteCount

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where two suites in different schemas have the 
-- same name. The two suites have no setup and teardown just tests.
-- Running the suite will trigger a system error.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Schemas#SuitesWithSameName2
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @SuiteCount           int

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckSchema'      ,
      @SuiteName           = 'SuiteB'              ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession     @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOneSystemError  @TestSessionId=@TestSessionId, @ExpectedErrorMessage='The suite name ''SuiteB'' appears to be duplicated across different schemas in database ''TSTCheckSchema''.'

   SET @SuiteCount = NULL
   SELECT @SuiteCount = COUNT(*) FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId AND SuiteName = 'SuiteB'
   EXEC TST.Assert.Equals 'There must be 2 suites SuiteB', 2, @SuiteCount
   
   SET @SuiteCount = NULL
   SELECT @SuiteCount = COUNT(*) FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId AND SchemaName = 'TestSchema4' AND SuiteName = 'SuiteB'
   EXEC TST.Assert.Equals 'There must be 1 suite SuiteB in schema TestSchema4', 1, @SuiteCount
   
   SET @SuiteCount = NULL
   SELECT @SuiteCount = COUNT(*) FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId AND SchemaName = 'TestSchema5' AND SuiteName = 'SuiteB'
   EXEC TST.Assert.Equals 'There must be 1 suite SuiteB in schema TestSchema5', 1, @SuiteCount

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where two test in the Anonimous suite having the 
-- same name are created in different schemas.
-- Running any of the tests will trigger a system error.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Schemas#TestsWithSameName
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @SuiteCount           int
   DECLARE @TestCount            int

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckSchema'      ,
      @TestName            = 'SQLTest_TestX'       ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession     @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOneSystemError  @TestSessionId=@TestSessionId, @ExpectedErrorMessage='The test name ''SQLTest_TestX'' appears to be duplicated across different schemas in database ''TSTCheckSchema''.'

   SET @SuiteCount = NULL
   SELECT @SuiteCount = COUNT(*) FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId AND SuiteName IS NULL
   EXEC TST.Assert.Equals 'There must be 1 anonymous suite', 1, @SuiteCount
   
   SET @TestCount = NULL
   SELECT @TestCount = COUNT(*) FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND SProcName = 'SQLTest_TestX'
   EXEC TST.Assert.Equals 'There must be 2 tests named SQLTest_TestX', 2, @TestCount

   SET @TestCount = NULL
   SELECT @TestCount = COUNT(*) FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND SchemaName = 'TestSchema6' AND SProcName = 'SQLTest_TestX'
   EXEC TST.Assert.Equals 'There must be 1 test named SQLTest_TestX in schema TestSchema6', 1, @TestCount

   SET @TestCount = NULL
   SELECT @TestCount = COUNT(*) FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND SchemaName = 'TestSchema7' AND SProcName = 'SQLTest_TestX'
   EXEC TST.Assert.Equals 'There must be 1 test named SQLTest_TestX in schema TestSchema7', 1, @TestCount
   
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where a suite has the SETUP, tests and TEARDOWN in 
-- different schemas.
-- Running the suite will trigger a system error.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Schemas#SuiteSpreadOverDifferentSchemas
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   DECLARE @SuiteCount           int
   DECLARE @TestCount            int

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckSchema'      ,
      @SuiteName           = 'SuiteX'              ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession     @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOneSystemError  @TestSessionId=@TestSessionId, @ExpectedErrorMessage='The suite name ''SuiteX'' appears to be duplicated across different schemas in database ''TSTCheckSchema''.'

   SET @SuiteCount = NULL
   SELECT @SuiteCount = COUNT(*) FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId AND SuiteName = 'SuiteX'
   EXEC TST.Assert.Equals 'There must be 4 suites SuiteX', 4, @SuiteCount
   
   SET @SuiteCount = NULL
   SELECT @SuiteCount = COUNT(*) FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId AND SchemaName = 'TestSchemaX1' AND SuiteName = 'SuiteX'
   EXEC TST.Assert.Equals 'There must be 1 suite SuiteX in schema TestSchemaX1', 1, @SuiteCount
   
   SET @SuiteCount = NULL
   SELECT @SuiteCount = COUNT(*) FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId AND SchemaName = 'TestSchemaX2' AND SuiteName = 'SuiteX'
   EXEC TST.Assert.Equals 'There must be 1 suite SuiteX in schema TestSchemaX2', 1, @SuiteCount

   SET @SuiteCount = NULL
   SELECT @SuiteCount = COUNT(*) FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId AND SchemaName = 'TestSchemaX3' AND SuiteName = 'SuiteX'
   EXEC TST.Assert.Equals 'There must be 1 suite SuiteX in schema TestSchemaX3', 1, @SuiteCount

   SET @SuiteCount = NULL
   SELECT @SuiteCount = COUNT(*) FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId AND SchemaName = 'TestSchemaX4' AND SuiteName = 'SuiteX'
   EXEC TST.Assert.Equals 'There must be 1 suite SuiteX in schema TestSchemaX4', 1, @SuiteCount

   SET @TestCount = NULL
   SELECT @TestCount = COUNT(*) FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND SchemaName = 'TestSchemaX1' AND SProcName = 'SQLTest_SETUP_SuiteX' AND SProcType = 'Setup'
   EXEC TST.Assert.Equals 'There must be 1 sproc SQLTest_SETUP_SuiteX in schema TestSchemaX1', 1, @TestCount

   SET @TestCount = NULL
   SELECT @TestCount = COUNT(*) FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND SchemaName = 'TestSchemaX2' AND SProcName = 'SQLTest_TEARDOWN_SuiteX' AND SProcType = 'Teardown'
   EXEC TST.Assert.Equals 'There must be 1 sproc SQLTest_TEARDOWN_SuiteX in schema TestSchemaX2', 1, @TestCount

   SET @TestCount = NULL
   SELECT @TestCount = COUNT(*) FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND SchemaName = 'TestSchemaX3' AND SProcName = 'SQLTest_SuiteX#TestA' AND SProcType = 'Test'
   EXEC TST.Assert.Equals 'There must be 1 sproc SQLTest_SuiteX#TestA in schema TestSchemaX3', 1, @TestCount

   SET @TestCount = NULL
   SELECT @TestCount = COUNT(*) FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND SchemaName = 'TestSchemaX4' AND SProcName = 'SQLTest_SuiteX#TestB' AND SProcType = 'Test'
   EXEC TST.Assert.Equals 'There must be 1 sproc SQLTest_SuiteX#TestB in schema TestSchemaX4', 1, @TestCount

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO


-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- END testing the test procedure in its own schema
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- START testing the view Data.TSTResultsEx
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

CREATE PROCEDURE dbo.SQLTest_TSTResultsEx#TestOnePassEntry
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   DECLARE @CountTSTResultsExEntries int

   DECLARE @ExpectedLogEntryId      int
   DECLARE @ExpectedSuiteId         int
   DECLARE @ExpectedSuiteName       sysname
   DECLARE @ExpectedSuiteStatus     char
   DECLARE @ExpectedTestId          int
   DECLARE @ExpectedSProcName       sysname
   DECLARE @ExpectedTestStatus      char
   DECLARE @ExpectedEntryType       char
   DECLARE @ExpectedLogMessage      nvarchar(max)

   DECLARE @ActualLogEntryId        int
   DECLARE @ActualSuiteId           int
   DECLARE @ActualSuiteName         sysname
   DECLARE @ActualSuiteStatus       char
   DECLARE @ActualTestId            int
   DECLARE @ActualSProcName         sysname
   DECLARE @ActualTestStatus        char
   DECLARE @ActualEntryType         char
   DECLARE @ActualLogMessage        nvarchar(max)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckView_TSTResultsEx',
      @TestName            = 'SQLTest_TestOnePassEntry',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   SELECT @CountTSTResultsExEntries = COUNT(*) FROM TST.Data.TSTResultsEx WHERE TestSessionId = @TestSessionId
   EXEC TST.Assert.Equals 'There must be 1 entry in TSTResultsEx', 1, @CountTSTResultsExEntries

   SELECT @ExpectedLogEntryId = LogEntryId FROM TST.Data.TestLog WHERE TestSessionId = @TestSessionId
   SELECT @ExpectedSuiteId = SuiteId FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId
   SELECT @ExpectedSuiteName = 'Anonymous'
   SELECT @ExpectedSuiteStatus = 'P'
   SELECT @ExpectedTestId = TestId FROM TST.Data.Test WHERE TestSessionId = @TestSessionId
   SELECT @ExpectedSProcName = 'SQLTest_TestOnePassEntry'
   SELECT @ExpectedTestStatus = 'P'
   SELECT @ExpectedEntryType = 'P'
   SELECT @ExpectedLogMessage = '%Test passing Assert.Equals in SQLTest_TestOnePassEntry%'
   
   SELECT   
      @ActualLogEntryId    = LogEntryId    ,
      @ActualSuiteId       = SuiteId       ,
      @ActualSuiteName     = SuiteName     ,
      @ActualSuiteStatus   = SuiteStatus   ,
      @ActualTestId        = TestId        ,
      @ActualSProcName     = SProcName     ,
      @ActualTestStatus    = TestStatus    ,
      @ActualEntryType     = EntryType     ,
      @ActualLogMessage    = LogMessage    
   FROM TST.Data.TSTResultsEx WHERE TestSessionId = @TestSessionId

   EXEC TST.Assert.Equals 'SuiteId'          , @ExpectedSuiteId       , @ActualSuiteId        
   EXEC TST.Assert.Equals 'SuiteName'        , @ExpectedSuiteName     , @ActualSuiteName      
   EXEC TST.Assert.Equals 'SuiteStatus'      , @ExpectedSuiteStatus   , @ActualSuiteStatus    
   EXEC TST.Assert.Equals 'TestId'           , @ExpectedTestId        , @ActualTestId         
   EXEC TST.Assert.Equals 'SProcName'        , @ExpectedSProcName     , @ActualSProcName      
   EXEC TST.Assert.Equals 'TestStatus'       , @ExpectedTestStatus    , @ActualTestStatus     
   EXEC TST.Assert.Equals 'EntryType'        , @ExpectedEntryType     , @ActualEntryType      
   EXEC TST.Assert.IsLike 'LogMessage'       , @ExpectedLogMessage    , @ActualLogMessage
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


CREATE PROCEDURE dbo.SQLTest_TSTResultsEx#TestOneLogEntry
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   DECLARE @CountTSTResultsExEntries int

   DECLARE @ExpectedSuiteId         int
   DECLARE @ExpectedTestId          int

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckView_TSTResultsEx',
      @TestName            = 'SQLTest_TestOneLogEntry',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   SELECT @CountTSTResultsExEntries = COUNT(*) FROM TST.Data.TSTResultsEx WHERE TestSessionId = @TestSessionId
   EXEC TST.Assert.Equals 'There must be 2 entries in TSTResultsEx', 2, @CountTSTResultsExEntries

   SELECT @ExpectedSuiteId = SuiteId FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId
   SELECT @ExpectedTestId = TestId FROM TST.Data.Test WHERE TestSessionId = @TestSessionId
   
   -- Create the test tables #ActualResult and #ExpectedResult
   CREATE TABLE #ExpectedResult (
      RowId          int PRIMARY KEY NOT NULL ,
      SuiteId        int NOT NULL,
      SuiteName      varchar(255) NOT NULL,
      SuiteStatus    char NOT NULL,
      TestId         int NOT NULL,
      SProcName      varchar(255) NOT NULL,
      TestStatus     char NOT NULL,
      EntryType      char NOT NULL
   )

   CREATE TABLE #ActualResult (
      RowId          int PRIMARY KEY NOT NULL ,
      SuiteId        int NOT NULL,
      SuiteName      varchar(255) NOT NULL,
      SuiteStatus    char NOT NULL,
      TestId         int NOT NULL,
      SProcName      varchar(255) NOT NULL,
      TestStatus     char NOT NULL,
      EntryType      char NOT NULL
   )

   -- This is the entry corresponding to the Assert.LogInfo call made by the sproc SQLTest_TestOneLogEntry
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (1, @ExpectedSuiteId, 'Anonymous', 'F', @ExpectedTestId, 'SQLTest_TestOneLogEntry', 'F', 'L')
   -- This is the entry corresponding to the message 'No Assert, Fail or Pass was invoked by this test...'
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (2, @ExpectedSuiteId, 'Anonymous', 'F', @ExpectedTestId, 'SQLTest_TestOneLogEntry', 'F', 'F')

   -- Store the actual data in #ExpectedResult
   INSERT INTO #ActualResult SELECT 
      ROW_NUMBER() OVER(ORDER BY LogEntryId),
      SuiteId       ,
      SuiteName     ,
      SuiteStatus   ,
      TestId        ,
      SProcName     ,
      TestStatus    ,
      EntryType     
   FROM TST.Data.TSTResultsEx 
   WHERE TestSessionId = @TestSessionId
   ORDER BY LogEntryId

   EXEC TST.Assert.TableEquals 'Validate Data.TSTResultsEx'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


CREATE PROCEDURE dbo.SQLTest_TSTResultsEx#TestOneFailEntry
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   DECLARE @CountTSTResultsExEntries int

   DECLARE @ExpectedLogEntryId      int
   DECLARE @ExpectedSuiteId         int
   DECLARE @ExpectedSuiteName       sysname
   DECLARE @ExpectedSuiteStatus     char
   DECLARE @ExpectedTestId          int
   DECLARE @ExpectedSProcName       sysname
   DECLARE @ExpectedTestStatus      char
   DECLARE @ExpectedEntryType       char
   DECLARE @ExpectedLogMessage      nvarchar(max)

   DECLARE @ActualLogEntryId        int
   DECLARE @ActualSuiteId           int
   DECLARE @ActualSuiteName         sysname
   DECLARE @ActualSuiteStatus       char
   DECLARE @ActualTestId            int
   DECLARE @ActualSProcName         sysname
   DECLARE @ActualTestStatus        char
   DECLARE @ActualEntryType         char
   DECLARE @ActualLogMessage        nvarchar(max)
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckView_TSTResultsEx',
      @TestName            = 'SQLTest_TestOneFailEntry',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   SELECT @CountTSTResultsExEntries = COUNT(*) FROM TST.Data.TSTResultsEx WHERE TestSessionId = @TestSessionId
   EXEC TST.Assert.Equals 'There must be 1 entry in TSTResultsEx', 1, @CountTSTResultsExEntries

   SELECT @ExpectedLogEntryId = LogEntryId FROM TST.Data.TestLog WHERE TestSessionId = @TestSessionId
   SELECT @ExpectedSuiteId = SuiteId FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId
   SELECT @ExpectedSuiteName = 'Anonymous'
   SELECT @ExpectedSuiteStatus = 'F'
   SELECT @ExpectedTestId = TestId FROM TST.Data.Test WHERE TestSessionId = @TestSessionId
   SELECT @ExpectedSProcName = 'SQLTest_TestOneFailEntry'
   SELECT @ExpectedTestStatus = 'F'
   SELECT @ExpectedEntryType = 'F'
   SELECT @ExpectedLogMessage = '%Test failing Assert.Equals in SQLTest_TestOneFailEntry%'
   
   SELECT   
      @ActualLogEntryId    = LogEntryId    ,
      @ActualSuiteId       = SuiteId       ,
      @ActualSuiteName     = SuiteName     ,
      @ActualSuiteStatus   = SuiteStatus   ,
      @ActualTestId        = TestId        ,
      @ActualSProcName     = SProcName     ,
      @ActualTestStatus    = TestStatus    ,
      @ActualEntryType     = EntryType     ,
      @ActualLogMessage    = LogMessage    
   FROM TST.Data.TSTResultsEx WHERE TestSessionId = @TestSessionId

   EXEC TST.Assert.Equals 'SuiteId'          , @ExpectedSuiteId       , @ActualSuiteId        
   EXEC TST.Assert.Equals 'SuiteName'        , @ExpectedSuiteName     , @ActualSuiteName      
   EXEC TST.Assert.Equals 'SuiteStatus'      , @ExpectedSuiteStatus   , @ActualSuiteStatus    
   EXEC TST.Assert.Equals 'TestId'           , @ExpectedTestId        , @ActualTestId         
   EXEC TST.Assert.Equals 'SProcName'        , @ExpectedSProcName     , @ActualSProcName      
   EXEC TST.Assert.Equals 'TestStatus'       , @ExpectedTestStatus    , @ActualTestStatus     
   EXEC TST.Assert.Equals 'EntryType'        , @ExpectedEntryType     , @ActualEntryType      
   EXEC TST.Assert.IsLike 'LogMessage'       , @ExpectedLogMessage    , @ActualLogMessage
   
   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


CREATE PROCEDURE dbo.SQLTest_TSTResultsEx#TestOneErrorEntry
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   DECLARE @CountTSTResultsExEntries int

   DECLARE @ExpectedLogEntryId      int
   DECLARE @ExpectedSuiteId         int
   DECLARE @ExpectedSuiteName       sysname
   DECLARE @ExpectedSuiteStatus     char
   DECLARE @ExpectedTestId          int
   DECLARE @ExpectedSProcName       sysname
   DECLARE @ExpectedTestStatus      char
   DECLARE @ExpectedEntryType       char
   DECLARE @ExpectedLogMessage      nvarchar(max)

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckView_TSTResultsEx',
      @TestName            = 'SQLTest_TestOneErrorEntry',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   SELECT @CountTSTResultsExEntries = COUNT(*) FROM TST.Data.TSTResultsEx WHERE TestSessionId = @TestSessionId
   EXEC TST.Assert.Equals 'There must be 2 entries in TSTResultsEx', 2, @CountTSTResultsExEntries

   SELECT @ExpectedSuiteId = SuiteId FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId
   SELECT @ExpectedTestId = TestId FROM TST.Data.Test WHERE TestSessionId = @TestSessionId
   
   -- Create the test tables #ActualResult and #ExpectedResult
   CREATE TABLE #ExpectedResult (
      RowId          int PRIMARY KEY NOT NULL ,
      SuiteId        int NOT NULL,
      SuiteName      varchar(255) NOT NULL,
      SuiteStatus    char NOT NULL,
      TestId         int NOT NULL,
      SProcName      varchar(255) NOT NULL,
      TestStatus     char NOT NULL,
      EntryType      char NOT NULL
   )

   CREATE TABLE #ActualResult (
      RowId          int PRIMARY KEY NOT NULL ,
      SuiteId        int NOT NULL,
      SuiteName      varchar(255) NOT NULL,
      SuiteStatus    char NOT NULL,
      TestId         int NOT NULL,
      SProcName      varchar(255) NOT NULL,
      TestStatus     char NOT NULL,
      EntryType      char NOT NULL
   )

   -- This is the entry corresponding to the Error message: 'An error occured during the execution of the test procedure ...'
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (1, @ExpectedSuiteId, 'Anonymous', 'F', @ExpectedTestId, 'SQLTest_TestOneErrorEntry', 'F', 'E')
   -- This is the entry corresponding to the Error message: 'The transaction is in an uncommitable state after the test procedure ...'
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (2, @ExpectedSuiteId, 'Anonymous', 'F', @ExpectedTestId, 'SQLTest_TestOneErrorEntry', 'F', 'E')

   -- Store the actual data in #ExpectedResult
   INSERT INTO #ActualResult SELECT 
      ROW_NUMBER() OVER(ORDER BY LogEntryId),
      SuiteId       ,
      SuiteName     ,
      SuiteStatus   ,
      TestId        ,
      SProcName     ,
      TestStatus    ,
      EntryType     
   FROM TST.Data.TSTResultsEx 
   WHERE TestSessionId = @TestSessionId
   ORDER BY LogEntryId

   EXEC TST.Assert.TableEquals 'Validate Data.TSTResultsEx'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


CREATE PROCEDURE dbo.SQLTest_TSTResultsEx#TestSuitePass
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   DECLARE @CountTSTResultsExEntries int

   DECLARE @ExpectedLogEntryId      int
   DECLARE @ExpectedSuiteId         int
   DECLARE @ExpectedSuiteName       sysname
   DECLARE @ExpectedSuiteStatus     char
   DECLARE @ExpectedTestId1         int
   DECLARE @ExpectedTestId2         int
   DECLARE @ExpectedSProcName       sysname
   DECLARE @ExpectedTestStatus      char
   DECLARE @ExpectedEntryType       char
   DECLARE @ExpectedLogMessage      nvarchar(max)

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckView_TSTResultsEx',
      @SuiteName           = 'SuitePass'           ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   SELECT @CountTSTResultsExEntries = COUNT(*) FROM TST.Data.TSTResultsEx WHERE TestSessionId = @TestSessionId
   EXEC TST.Assert.Equals 'There must be 2 entries in TSTResultsEx', 2, @CountTSTResultsExEntries

   SELECT @ExpectedSuiteId = SuiteId FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId
   SELECT TOP 1 @ExpectedTestId1 = TestId FROM TST.Data.Test WHERE TestSessionId = @TestSessionId
   SELECT TOP 1 @ExpectedTestId2 = TestId FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND TestId > @ExpectedTestId1
   
   -- Create the test tables #ActualResult and #ExpectedResult
   CREATE TABLE #ExpectedResult (
      RowId          int PRIMARY KEY NOT NULL ,
      SuiteId        int NOT NULL,
      SuiteName      varchar(255) NOT NULL,
      SuiteStatus    char NOT NULL,
      TestId         int NOT NULL,
      SProcName      varchar(255) NOT NULL,
      TestStatus     char NOT NULL,
      EntryType      char NOT NULL
   )

   CREATE TABLE #ActualResult (
      RowId          int PRIMARY KEY NOT NULL ,
      SuiteId        int NOT NULL,
      SuiteName      varchar(255) NOT NULL,
      SuiteStatus    char NOT NULL,
      TestId         int NOT NULL,
      SProcName      varchar(255) NOT NULL,
      TestStatus     char NOT NULL,
      EntryType      char NOT NULL
   )

   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (1, @ExpectedSuiteId, 'SuitePass', 'P', @ExpectedTestId1, 'SQLTest_SuitePass#TestPass1', 'P', 'P')
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (2, @ExpectedSuiteId, 'SuitePass', 'P', @ExpectedTestId2, 'SQLTest_SuitePass#TestPass2', 'P', 'P')

   -- Store the actual data in #ExpectedResult
   INSERT INTO #ActualResult SELECT 
      ROW_NUMBER() OVER(ORDER BY LogEntryId),
      SuiteId       ,
      SuiteName     ,
      SuiteStatus   ,
      TestId        ,
      SProcName     ,
      TestStatus    ,
      EntryType     
   FROM TST.Data.TSTResultsEx 
   WHERE TestSessionId = @TestSessionId
   ORDER BY LogEntryId

   EXEC TST.Assert.TableEquals 'Validate Data.TSTResultsEx'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

CREATE PROCEDURE dbo.SQLTest_TSTResultsEx#TestSuiteOneFailure
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   DECLARE @CountTSTResultsExEntries int

   DECLARE @ExpectedLogEntryId      int
   DECLARE @ExpectedSuiteId         int
   DECLARE @ExpectedSuiteName       sysname
   DECLARE @ExpectedSuiteStatus     char
   DECLARE @ExpectedTestId1         int
   DECLARE @ExpectedTestId2         int
   DECLARE @ExpectedSProcName       sysname
   DECLARE @ExpectedTestStatus      char
   DECLARE @ExpectedEntryType       char
   DECLARE @ExpectedLogMessage      nvarchar(max)

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckView_TSTResultsEx',
      @SuiteName           = 'SuiteOneFailure'     ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   SELECT @CountTSTResultsExEntries = COUNT(*) FROM TST.Data.TSTResultsEx WHERE TestSessionId = @TestSessionId
   EXEC TST.Assert.Equals 'There must be 4 entries in TSTResultsEx', 4, @CountTSTResultsExEntries

   SELECT @ExpectedSuiteId = SuiteId FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId
   SELECT TOP 1 @ExpectedTestId1 = TestId FROM TST.Data.Test WHERE TestSessionId = @TestSessionId
   SELECT TOP 1 @ExpectedTestId2 = TestId FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND TestId > @ExpectedTestId1
   
   -- Create the test tables #ActualResult and #ExpectedResult
   CREATE TABLE #ExpectedResult (
      RowId          int PRIMARY KEY NOT NULL ,
      SuiteId        int NOT NULL,
      SuiteName      varchar(255) NOT NULL,
      SuiteStatus    char NOT NULL,
      TestId         int NOT NULL,
      SProcName      varchar(255) NOT NULL,
      TestStatus     char NOT NULL,
      EntryType      char NOT NULL
   )

   CREATE TABLE #ActualResult (
      RowId          int PRIMARY KEY NOT NULL ,
      SuiteId        int NOT NULL,
      SuiteName      varchar(255) NOT NULL,
      SuiteStatus    char NOT NULL,
      TestId         int NOT NULL,
      SProcName      varchar(255) NOT NULL,
      TestStatus     char NOT NULL,
      EntryType      char NOT NULL
   )

   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (1, @ExpectedSuiteId, 'SuiteOneFailure', 'F', @ExpectedTestId1, 'SQLTest_SuiteOneFailure#Test_A_Pass', 'P', 'P')
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (2, @ExpectedSuiteId, 'SuiteOneFailure', 'F', @ExpectedTestId1, 'SQLTest_SuiteOneFailure#Test_A_Pass', 'P', 'P')
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (3, @ExpectedSuiteId, 'SuiteOneFailure', 'F', @ExpectedTestId2, 'SQLTest_SuiteOneFailure#Test_B_Fail', 'F', 'P')
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (4, @ExpectedSuiteId, 'SuiteOneFailure', 'F', @ExpectedTestId2, 'SQLTest_SuiteOneFailure#Test_B_Fail', 'F', 'F')

   -- Store the actual data in #ExpectedResult
   INSERT INTO #ActualResult SELECT 
      ROW_NUMBER() OVER(ORDER BY LogEntryId),
      SuiteId       ,
      SuiteName     ,
      SuiteStatus   ,
      TestId        ,
      SProcName     ,
      TestStatus    ,
      EntryType     
   FROM TST.Data.TSTResultsEx 
   WHERE TestSessionId = @TestSessionId
   ORDER BY LogEntryId

   EXEC TST.Assert.TableEquals 'Validate Data.TSTResultsEx'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

CREATE PROCEDURE dbo.SQLTest_TSTResultsEx#TestSuiteOneError
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   DECLARE @CountTSTResultsExEntries int

   DECLARE @ExpectedLogEntryId      int
   DECLARE @ExpectedSuiteId         int
   DECLARE @ExpectedSuiteName       sysname
   DECLARE @ExpectedSuiteStatus     char
   DECLARE @ExpectedTestId1         int
   DECLARE @ExpectedTestId2         int
   DECLARE @ExpectedSProcName       sysname
   DECLARE @ExpectedTestStatus      char
   DECLARE @ExpectedEntryType       char
   DECLARE @ExpectedLogMessage      nvarchar(max)

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckView_TSTResultsEx',
      @SuiteName           = 'SuiteOneError'       ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   SELECT @CountTSTResultsExEntries = COUNT(*) FROM TST.Data.TSTResultsEx WHERE TestSessionId = @TestSessionId
   EXEC TST.Assert.Equals 'There must be 5 entries in TSTResultsEx', 5, @CountTSTResultsExEntries

   SELECT @ExpectedSuiteId = SuiteId FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId
   SELECT TOP 1 @ExpectedTestId1 = TestId FROM TST.Data.Test WHERE TestSessionId = @TestSessionId
   SELECT TOP 1 @ExpectedTestId2 = TestId FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND TestId > @ExpectedTestId1
   
   -- Create the test tables #ActualResult and #ExpectedResult
   CREATE TABLE #ExpectedResult (
      RowId          int PRIMARY KEY NOT NULL ,
      SuiteId        int NOT NULL,
      SuiteName      varchar(255) NOT NULL,
      SuiteStatus    char NOT NULL,
      TestId         int NOT NULL,
      SProcName      varchar(255) NOT NULL,
      TestStatus     char NOT NULL,
      EntryType      char NOT NULL
   )

   CREATE TABLE #ActualResult (
      RowId          int PRIMARY KEY NOT NULL ,
      SuiteId        int NOT NULL,
      SuiteName      varchar(255) NOT NULL,
      SuiteStatus    char NOT NULL,
      TestId         int NOT NULL,
      SProcName      varchar(255) NOT NULL,
      TestStatus     char NOT NULL,
      EntryType      char NOT NULL
   )

   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (1, @ExpectedSuiteId, 'SuiteOneError', 'F', @ExpectedTestId1, 'SQLTest_SuiteOneError#Test_A_Pass', 'P', 'P')
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (2, @ExpectedSuiteId, 'SuiteOneError', 'F', @ExpectedTestId1, 'SQLTest_SuiteOneError#Test_A_Pass', 'P', 'P')
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (3, @ExpectedSuiteId, 'SuiteOneError', 'F', @ExpectedTestId2, 'SQLTest_SuiteOneError#Test_B_Error', 'F', 'P')

   -- This is the entry corresponding to the Error message: 'An error occured during the execution of the test procedure ...'
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (4, @ExpectedSuiteId, 'SuiteOneError', 'F', @ExpectedTestId2, 'SQLTest_SuiteOneError#Test_B_Error', 'F', 'E')
   -- This is the entry corresponding to the Error message: 'The transaction is in an uncommitable state after the test procedure ...'
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (5, @ExpectedSuiteId, 'SuiteOneError', 'F', @ExpectedTestId2, 'SQLTest_SuiteOneError#Test_B_Error', 'F', 'E')

   -- Store the actual data in #ExpectedResult
   INSERT INTO #ActualResult SELECT 
      ROW_NUMBER() OVER(ORDER BY LogEntryId),
      SuiteId       ,
      SuiteName     ,
      SuiteStatus   ,
      TestId        ,
      SProcName     ,
      TestStatus    ,
      EntryType     
   FROM TST.Data.TSTResultsEx 
   WHERE TestSessionId = @TestSessionId
   ORDER BY LogEntryId

   EXEC TST.Assert.TableEquals 'Validate Data.TSTResultsEx'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

CREATE PROCEDURE dbo.SQLTest_TSTResultsEx#TestSuiteOneFailureOneError
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   DECLARE @CountTSTResultsExEntries int

   DECLARE @ExpectedLogEntryId      int
   DECLARE @ExpectedSuiteId         int
   DECLARE @ExpectedSuiteName       sysname
   DECLARE @ExpectedSuiteStatus     char
   DECLARE @ExpectedTestId1         int
   DECLARE @ExpectedTestId2         int
   DECLARE @ExpectedTestId3         int
   DECLARE @ExpectedSProcName       sysname
   DECLARE @ExpectedTestStatus      char
   DECLARE @ExpectedEntryType       char
   DECLARE @ExpectedLogMessage      nvarchar(max)

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckView_TSTResultsEx',
      @SuiteName           = 'SuiteOneFailureOneError'  ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   SELECT @CountTSTResultsExEntries = COUNT(*) FROM TST.Data.TSTResultsEx WHERE TestSessionId = @TestSessionId
   EXEC TST.Assert.Equals 'There must be 5 entries in TSTResultsEx', 7, @CountTSTResultsExEntries

   SELECT @ExpectedSuiteId = SuiteId FROM TST.Data.Suite WHERE TestSessionId = @TestSessionId
   SELECT TOP 1 @ExpectedTestId1 = TestId FROM TST.Data.Test WHERE TestSessionId = @TestSessionId
   SELECT TOP 1 @ExpectedTestId2 = TestId FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND TestId > @ExpectedTestId1
   SELECT TOP 1 @ExpectedTestId3 = TestId FROM TST.Data.Test WHERE TestSessionId = @TestSessionId AND TestId > @ExpectedTestId2
   
   -- Create the test tables #ActualResult and #ExpectedResult
   CREATE TABLE #ExpectedResult (
      RowId          int PRIMARY KEY NOT NULL ,
      SuiteId        int NOT NULL,
      SuiteName      varchar(255) NOT NULL,
      SuiteStatus    char NOT NULL,
      TestId         int NOT NULL,
      SProcName      varchar(255) NOT NULL,
      TestStatus     char NOT NULL,
      EntryType      char NOT NULL
   )

   CREATE TABLE #ActualResult (
      RowId          int PRIMARY KEY NOT NULL ,
      SuiteId        int NOT NULL,
      SuiteName      varchar(255) NOT NULL,
      SuiteStatus    char NOT NULL,
      TestId         int NOT NULL,
      SProcName      varchar(255) NOT NULL,
      TestStatus     char NOT NULL,
      EntryType      char NOT NULL
   )

   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (1, @ExpectedSuiteId, 'SuiteOneFailureOneError', 'F', @ExpectedTestId1, 'SQLTest_SuiteOneFailureOneError#Test_A_Pass', 'P', 'P')
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (2, @ExpectedSuiteId, 'SuiteOneFailureOneError', 'F', @ExpectedTestId1, 'SQLTest_SuiteOneFailureOneError#Test_A_Pass', 'P', 'P')

   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (3, @ExpectedSuiteId, 'SuiteOneFailureOneError', 'F', @ExpectedTestId2, 'SQLTest_SuiteOneFailureOneError#Test_B_Fail', 'F', 'P')
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (4, @ExpectedSuiteId, 'SuiteOneFailureOneError', 'F', @ExpectedTestId2, 'SQLTest_SuiteOneFailureOneError#Test_B_Fail', 'F', 'F')

   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (5, @ExpectedSuiteId, 'SuiteOneFailureOneError', 'F', @ExpectedTestId3, 'SQLTest_SuiteOneFailureOneError#Test_C_Error', 'F', 'P')

   -- This is the entry corresponding to the Error message: 'An error occured during the execution of the test procedure ...'
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (6, @ExpectedSuiteId, 'SuiteOneFailureOneError', 'F', @ExpectedTestId3, 'SQLTest_SuiteOneFailureOneError#Test_C_Error', 'F', 'E')
   -- This is the entry corresponding to the Error message: 'The transaction is in an uncommitable state after the test procedure ...'
   INSERT INTO #ExpectedResult (RowId, SuiteId, SuiteName, SuiteStatus, TestId, SProcName, TestStatus, EntryType) VALUES (7, @ExpectedSuiteId, 'SuiteOneFailureOneError', 'F', @ExpectedTestId3, 'SQLTest_SuiteOneFailureOneError#Test_C_Error', 'F', 'E')

   -- Store the actual data in #ExpectedResult
   INSERT INTO #ActualResult SELECT 
      ROW_NUMBER() OVER(ORDER BY LogEntryId),
      SuiteId       ,
      SuiteName     ,
      SuiteStatus   ,
      TestId        ,
      SProcName     ,
      TestStatus    ,
      EntryType     
   FROM TST.Data.TSTResultsEx 
   WHERE TestSessionId = @TestSessionId
   ORDER BY LogEntryId

   EXEC TST.Assert.TableEquals 'Validate Data.TSTResultsEx'

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- END testing the view Data.TSTResultsEx
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- START testing the test session SETUP/TEARDOWN. 
-- These are scenarios where where pre-transaction setup, post-transaction teardown and 
-- anonymous suite setup and teardown are in place.
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- =======================================================================
-- Test the case where we have the test session SETUP/TEARDOWN and  
-- a suite with two passing tests.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#TestSuite01
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTestSession'    ,
      @SuiteName           = 'Suite1'                 ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite1'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_Suite1'       , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_Suite1'    , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite1#TestA'       , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite1#TestB'       , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite1'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestA', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite1#TestA'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestA', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Passing test in SQLTest_Suite1#TestA%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestA', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite1'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestA', @ExpectedLogEntryCount=4

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite1'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite1#TestB'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Passing test in SQLTest_Suite1#TestB%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite1'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @ExpectedLogEntryCount=4

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where we have the test session SETUP/TEARDOWN and  
-- a suite with one failing test and one passing test.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#TestSuite02
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTestSession'    ,
      @SuiteName           = 'Suite2'                 ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite2'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_Suite2'       , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_Suite2'    , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite2#TestA'       , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite2#TestB'       , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite2'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestA', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite2#TestA'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestA', @LogIndex=3, @ExpectedLogType='F', @ExpectedLogMessage='%Failing test in SQLTest_Suite2#TestA%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestA', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite2'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestA', @ExpectedLogEntryCount=4

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite2'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestB', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite2#TestB'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestB', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Passing test in SQLTest_Suite2#TestB%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestB', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite2'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestB', @ExpectedLogEntryCount=4

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where we have the test session SETUP/TEARDOWN and  
-- a suite with one test failing due to a runtime error and one passing test.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#TestSuite03
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTestSession'    ,
      @SuiteName           = 'Suite3'                 ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite3'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_Suite3'       , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_Suite3'    , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite3#TestA'       , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite3#TestB'       , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite3'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite3#TestA'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='An error occured during the execution of the test procedure ''^[TSTCheckTestSession^].^[dbo^].^[SQLTest_Suite3#TestA^]''. Error: 245%', @EscapeCharacter = '^'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=4, @ExpectedLogType='E', @ExpectedLogMessage='The transaction is in an uncommitable state after the test procedure ''[TSTCheckTestSession].[dbo].[SQLTest_Suite3#TestA]'' has failed. A rollback was forced. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=5, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite3'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @ExpectedLogEntryCount=5

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite3'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestB', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite3#TestB'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestB', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Passing test in SQLTest_Suite3#TestB%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestB', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite3'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestB', @ExpectedLogEntryCount=4

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where we have the test session SETUP/TEARDOWN and  
-- a suite where the setup has a failing assert.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#TestSuite04
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTestSession'    ,
      @SuiteName           = 'Suite4'                 ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite4'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_Suite4'       , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_Suite4'    , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite4#TestA'       , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite4#TestB'       , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite4#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite4'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite4#TestA', @LogIndex=2, @ExpectedLogType='F', @ExpectedLogMessage='%Failing test in SQLTest_SETUP_Suite4%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite4#TestA', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite4'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite4#TestA', @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite4#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite4'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite4#TestB', @LogIndex=2, @ExpectedLogType='F', @ExpectedLogMessage='%Failing test in SQLTest_SETUP_Suite4%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite4#TestB', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite4'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite4#TestB', @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where we have the test session SETUP/TEARDOWN and  
-- a suite where the setup procedure will 
-- cause an error by registering an expected error.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#TestSuite05
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTestSession'    ,
      @SuiteName           = 'Suite5'                 ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite5'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_Suite5'       , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_Suite5'    , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite5#TestA'       , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite5#TestB'       , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite5#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite5'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite5#TestA', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='A setup procedure cannot invoke RegisterExpectedError. RegisterExpectedError can only be invoked by a test procedure before the error is raised.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite5#TestA', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite5'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite5#TestA', @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite5#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite5'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite5#TestA', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='A setup procedure cannot invoke RegisterExpectedError. RegisterExpectedError can only be invoked by a test procedure before the error is raised.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite5#TestB', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite5'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite5#TestB', @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where we have the test session SETUP/TEARDOWN and  
-- a suite where the setup procedure will have a run time error.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#TestSuite06
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTestSession'    ,
      @SuiteName           = 'Suite6'                 ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite6'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_Suite6'       , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_Suite6'    , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite6#TestA'       , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite6#TestB'       , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite6#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite6'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite6#TestA', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='An error occured during the execution of the test procedure ''^[TSTCheckTestSession^].^[dbo^].^[SQLTest_SETUP_Suite6^]''. Error: 245%', @EscapeCharacter = '^'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite6#TestA', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction is in an uncommitable state after the setup procedure ''[TSTCheckTestSession].[dbo].[SQLTest_SETUP_Suite6]'' has failed. A rollback was forced. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite6#TestA', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite6'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite6#TestA', @ExpectedLogEntryCount=4

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite6#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite6'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite6#TestB', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='An error occured during the execution of the test procedure ''^[TSTCheckTestSession^].^[dbo^].^[SQLTest_SETUP_Suite6^]''. Error: 245%', @EscapeCharacter = '^'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite6#TestB', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction is in an uncommitable state after the setup procedure ''[TSTCheckTestSession].[dbo].[SQLTest_SETUP_Suite6]'' has failed. A rollback was forced. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite6#TestB', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite6'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite6#TestB', @ExpectedLogEntryCount=4

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where we have the test session SETUP/TEARDOWN and  
-- a suite with one failing test and one passing test. 
-- The suite teardown also fails.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#TestSuite07
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTestSession'    ,
      @SuiteName           = 'Suite7'                 ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite7'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_Suite7'       , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_Suite7'    , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite7#TestA'       , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite7#TestB'       , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite7#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite7'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite7#TestA', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite7#TestA'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite7#TestA', @LogIndex=3, @ExpectedLogType='F', @ExpectedLogMessage='%Failing test in SQLTest_Suite7#TestA%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite7#TestA', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite7'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite7#TestA', @LogIndex=5, @ExpectedLogType='F', @ExpectedLogMessage='%Failing test in SQLTest_TEARDOWN_Suite7%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite7#TestA', @ExpectedLogEntryCount=5

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite7#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite7'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite7#TestB', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite7#TestB'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite7#TestB', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Passing test in SQLTest_Suite7#TestB%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite7#TestB', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite7'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite7#TestB', @LogIndex=5, @ExpectedLogType='F', @ExpectedLogMessage='%Failing test in SQLTest_TEARDOWN_Suite7%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite7#TestB', @ExpectedLogEntryCount=5

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where we have the test session SETUP/TEARDOWN and  
-- a suite with one failing test and one passing test. 
-- The suite teardown also causes an error by registering an expected error.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#TestSuite08
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTestSession'    ,
      @SuiteName           = 'Suite8'                 ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite8'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_Suite8'       , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_Suite8'    , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite8#TestA'       , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite8#TestB'       , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite8#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite8'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite8#TestA', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite8#TestA'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite8#TestA', @LogIndex=3, @ExpectedLogType='F', @ExpectedLogMessage='%Failing test in SQLTest_Suite8#TestA%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite8#TestA', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite8'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite8#TestA', @LogIndex=5, @ExpectedLogType='E', @ExpectedLogMessage='A teardown procedure cannot invoke RegisterExpectedError. RegisterExpectedError can only be invoked by a test procedure before the error is raised.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite8#TestA', @ExpectedLogEntryCount=5

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite8#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite8'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite8#TestB', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite8#TestB'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite8#TestB', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Passing test in SQLTest_Suite8#TestB%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite8#TestB', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite8'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite8#TestA', @LogIndex=5, @ExpectedLogType='E', @ExpectedLogMessage='A teardown procedure cannot invoke RegisterExpectedError. RegisterExpectedError can only be invoked by a test procedure before the error is raised.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite8#TestB', @ExpectedLogEntryCount=5

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where we have the test session SETUP/TEARDOWN and  
-- a suite with one failing test and one passing test. 
-- The suite teardown also fails due to a runtime error.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#TestSuite09
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckTestSession'    ,
      @SuiteName           = 'Suite9'                 ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite9'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_Suite9'       , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_Suite9'    , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite9#TestA'       , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite9#TestB'       , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite9#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite9'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite9#TestA', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite9#TestA'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite9#TestA', @LogIndex=3, @ExpectedLogType='F', @ExpectedLogMessage='%Failing test in SQLTest_Suite9#TestA%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite9#TestA', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite9'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite9#TestA', @LogIndex=5, @ExpectedLogType='E', @ExpectedLogMessage='An error occured during the execution of the test procedure ''^[TSTCheckTestSession^].^[dbo^].^[SQLTest_TEARDOWN_Suite9^]''. Error: 245%', @EscapeCharacter = '^'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite9#TestA', @LogIndex=6, @ExpectedLogType='E', @ExpectedLogMessage='The transaction is in an uncommitable state after the teardown procedure ''[TSTCheckTestSession].[dbo].[SQLTest_TEARDOWN_Suite9]'' has failed. A rollback was forced.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite9#TestA', @ExpectedLogEntryCount=6

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite9#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite9'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite9#TestB', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite9#TestB'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite9#TestB', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Passing test in SQLTest_Suite9#TestB%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite9#TestB', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite9'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite9#TestA', @LogIndex=5, @ExpectedLogType='E', @ExpectedLogMessage='An error occured during the execution of the test procedure ''^[TSTCheckTestSession^].^[dbo^].^[SQLTest_TEARDOWN_Suite9^]''. Error: 245%', @EscapeCharacter = '^'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite9#TestA', @LogIndex=6, @ExpectedLogType='E', @ExpectedLogMessage='The transaction is in an uncommitable state after the teardown procedure ''[TSTCheckTestSession].[dbo].[SQLTest_TEARDOWN_Suite9]'' has failed. A rollback was forced.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite9#TestB', @ExpectedLogEntryCount=6

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- =======================================================================
-- Test the case where we have the test session SETUP/TEARDOWN and  
-- one isolated test that is passing.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#Test01
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTestSession'    ,
      @TestName            = 'SQLTest_Test1'          ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName=null
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test1'              , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Test1'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Passing test in SQLTest_Test1%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @ExpectedLogEntryCount=2

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where we have the test session SETUP/TEARDOWN and  
-- one isolated test that is failing.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#Test02
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTestSession'    ,
      @TestName            = 'SQLTest_Test2'          ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName=null
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test2'              , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test2', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Test2'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test2', @LogIndex=2, @ExpectedLogType='F', @ExpectedLogMessage='%Failing test in SQLTest_Test2%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test2', @ExpectedLogEntryCount=2

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where we have the test session SETUP/TEARDOWN and  
-- one isolated test that is failing.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#Test03
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTestSession'    ,
      @TestName            = 'SQLTest_Test3'          ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName=null
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test3'              , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test3', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Test3'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test3', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='An error occured during the execution of the test procedure ''^[TSTCheckTestSession^].^[dbo^].^[SQLTest_Test3^]''. Error: 245%', @EscapeCharacter = '^'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test3', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The transaction is in an uncommitable state after the test procedure ''[TSTCheckTestSession].[dbo].[SQLTest_Test3]'' has failed. A rollback was forced. The TEARDOWN if any will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test3', @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO


-- =======================================================================
-- Test the case where we have the test session SETUP/TEARDOWN and  
-- we run the test over one entire database.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#TestWholeDB
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunAll
      @TestDatabaseName    = 'TSTCheckTestSession2'   ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName=null
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite1'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite2'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'       , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'    , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_Suite1'        , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_Suite1'     , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite1#TestA'        , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite1#TestB'        , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SETUP_Suite2'        , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_Suite2'     , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite2#TestA'        , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Suite2#TestB'        , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test1'               , @SProcType='Test'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TestDistinctName'    , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Check the count of session setup procedures%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Check the count of suite setup procedures%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=4, @ExpectedLogType='P', @ExpectedLogMessage='%Check the count of suite teardown procedures%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Check the count of session teardown procedures%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=6, @ExpectedLogType='P', @ExpectedLogMessage='%Check the count of test procedures%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=7, @ExpectedLogType='P', @ExpectedLogMessage='%Check the presence of one specific test%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=7

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Check the count of session setup procedures%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Check the count of suite setup procedures%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=4, @ExpectedLogType='P', @ExpectedLogMessage='%Check the count of suite teardown procedures%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=5, @ExpectedLogType='P', @ExpectedLogMessage='%Check the count of session teardown procedures%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=6, @ExpectedLogType='P', @ExpectedLogMessage='%Check the count of test procedures%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=7, @ExpectedLogType='P', @ExpectedLogMessage='%Check the presence of one specific test%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=7

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where we have the test session SETUP/TEARDOWN and  
-- we run the test over one entire database. The database has one test
-- This will be the baseline for the next few tests - just to prove that the 
-- passing case is behaving as expected
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#SessionOK
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunAll
      @TestDatabaseName    = 'TSTCheckTestSessionErr0',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName=null
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test1'              , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Test1'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Passing test in SQLTest_Test1%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @ExpectedLogEntryCount=2

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where the test session setup has a failing assert
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#SessionSetupFail_1
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunAll
      @TestDatabaseName    = 'TSTCheckTestSessionErr1',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName=null
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test1'              , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=2, @ExpectedLogType='F', @ExpectedLogMessage='%Failing test in SQLTest_SESSION_SETUP%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The test session will be aborted. No tests will be run. The execution will continue with the test session teardown.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @ExpectedLogEntryCount=0

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1


   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where the test session setup causes an error by 
-- registering an expected error.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#SessionSetupFail_2
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunAll
      @TestDatabaseName    = 'TSTCheckTestSessionErr2',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName=null
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test1'              , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='The test session setup procedure cannot invoke RegisterExpectedError. RegisterExpectedError can only be invoked by a test procedure before the error is raised.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The test session will be aborted. No tests will be run. The execution will continue with the test session teardown.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @ExpectedLogEntryCount=0

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where the test session setup has a runtime error
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#SessionSetupFail_3
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunAll
      @TestDatabaseName    = 'TSTCheckTestSessionErr3',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName=null
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test1'              , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='An error occured during the execution of the test procedure ''^[TSTCheckTestSessionErr3^].^[dbo^].^[SQLTest_SESSION_SETUP^]''. Error: 245%', @EscapeCharacter = '^'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The test session will be aborted. No tests will be run. The execution will continue with the test session teardown.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @ExpectedLogEntryCount=0

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where the test session teardown has a failing assert
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#SessionSetupFail_4
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunAll
      @TestDatabaseName    = 'TSTCheckTestSessionErr4',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName=null
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test1'              , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Test1'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Passing test in SQLTest_Test1%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @ExpectedLogEntryCount=2

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=2, @ExpectedLogType='F', @ExpectedLogMessage='%Failing test in SQLTest_SESSION_TEARDOWN%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=2

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where the test session teardown causes an error by 
-- registering an expected error.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#SessionSetupFail_5
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunAll
      @TestDatabaseName    = 'TSTCheckTestSessionErr5',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName=null
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test1'              , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Test1'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Passing test in SQLTest_Test1%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @ExpectedLogEntryCount=2

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='The test session teardown procedure cannot invoke RegisterExpectedError. RegisterExpectedError can only be invoked by a test procedure before the error is raised.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=2

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where the test session teardown has a runtime error.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#SessionSetupFail_6
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunAll
      @TestDatabaseName    = 'TSTCheckTestSessionErr6',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName=null
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionSetup#'
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='#SessionTeardown#'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_SETUP'      , @SProcType='SetupS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SESSION_TEARDOWN'   , @SProcType='TeardownS'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test1'              , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP', @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Test1'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Passing test in SQLTest_Test1%'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @ExpectedLogEntryCount=2

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='An error occured during the execution of the test procedure ''^[TSTCheckTestSessionErr6^].^[dbo^].^[SQLTest_SESSION_TEARDOWN^]''. Error: 245%', @EscapeCharacter = '^'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN', @ExpectedLogEntryCount=2

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where there are two test session setup procedures.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#SessionSetupFail_7
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunAll
      @TestDatabaseName    = 'TSTCheckTestSessionErr7',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOneSystemError @TestSessionId=@TestSessionId, @ExpectedErrorMessage='You cannot define more than one test session setup procedures [SQLTest_SESSION_SETUP].'
   EXEC dbo.ValidateNoSuitesTestsOrTestLog @TestSessionId=@TestSessionId

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case where there are two test session teardown procedures.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_SessionSetupTeardown#SessionSetupFail_8
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunAll
      @TestDatabaseName    = 'TSTCheckTestSessionErr8',
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOneSystemError @TestSessionId=@TestSessionId, @ExpectedErrorMessage='You cannot define more than one test session teardown procedures [SQLTest_SESSION_TEARDOWN].'
   EXEC dbo.ValidateNoSuitesTestsOrTestLog @TestSessionId=@TestSessionId

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- END testing the test session SETUP/TEARDOWN. 
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- START testing the IsTableNotEmpty / IsTableEmpty API
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- =======================================================================
-- Testing the case where IsTableNotEmpty passes
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_IsTableNotEmpty#TestPass
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTableEmptyOrNot'      ,
      @TestName            = 'SQLTest_IsTableNotEmptyPass'  ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IsTableNotEmptyPass', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='%Test Assert.IsTableNotEmpty in SQLTest_IsTableNotEmptyPass%Table #ActualResult has one or more rows.'
         
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where IsTableNotEmpty fails
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_IsTableNotEmpty#TestFail
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTableEmptyOrNot'      ,
      @TestName            = 'SQLTest_IsTableNotEmptyFail'  ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IsTableNotEmptyFail', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.IsTableNotEmpty in SQLTest_IsTableNotEmptyFail%Table #ActualResult is empty.'
         
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where IsTableNotEmpty fails because #ActualResult
-- is not created
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_IsTableNotEmpty#NoActualTableCreated
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTableEmptyOrNot'      ,
      @TestName            = 'SQLTest_IsTableNotEmptyNoActualTableCreated'  ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IsTableNotEmptyNoActualTableCreated', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='%Test Assert.IsTableNotEmpty in SQLTest_IsTableNotEmptyNoActualTableCreated%#ActualResult table was not created.'
         
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where IsTableEmpty passes
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_IsTableEmpty#TestPass
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTableEmptyOrNot'      ,
      @TestName            = 'SQLTest_IsTableEmptyPass'  ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IsTableEmptyPass', 
         @ExpectedEntryType='P', 
         @ExpectedLogMessageLike='%Test Assert.IsTableEmpty in SQLTest_IsTableEmptyPass%Table #ActualResult is empty.'
         
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where IsTableEmpty fails
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_IsTableEmpty#TestFail
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTableEmptyOrNot'      ,
      @TestName            = 'SQLTest_IsTableEmptyFail'  ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IsTableEmptyFail', 
         @ExpectedEntryType='F', 
         @ExpectedLogMessageLike='%Test Assert.IsTableEmpty in SQLTest_IsTableEmptyFail%Table #ActualResult has one or more rows.'
         
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where IsTableEmpty fails because #ActualResult
-- is not created
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_IsTableEmpty#NoActualTableCreated
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTableEmptyOrNot'      ,
      @TestName            = 'SQLTest_IsTableEmptyNoActualTableCreated'  ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateSingleTestResults
         @TestSessionId=@TestSessionId, 
         @SuiteName=NULL, 
         @SProcName='SQLTest_IsTableEmptyNoActualTableCreated', 
         @ExpectedEntryType='E', 
         @ExpectedLogMessageLike='%Test Assert.IsTableEmpty in SQLTest_IsTableEmptyNoActualTableCreated%#ActualResult table was not created.'
         
   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- END testing the IsTableNotEmpty / IsTableEmpty API
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- START testing the Transaction Errors scenarios
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- =======================================================================
-- Testing the case where a trigger raises an expected error
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TriggerWithErrorPass
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTransactionErrors' ,
      @TestName            = 'SQLTest_TriggerWithError'  ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                             @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                          @TestSessionId=@TestSessionId
   EXEC dbo.ValidateTestButNoSuiteSetupTeardownRecorded     @TestSessionId=@TestSessionId, @SProcName='SQLTest_TriggerWithError'

   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_TriggerWithError'       , @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TriggerWithError'
   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_TriggerWithError'       , @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='The transaction is in an uncommitable state after the test procedure ''[TSTCheckTransactionErrors].[dbo].[SQLTest_TriggerWithError]'' has failed. A rollback was forced but the test will complete.'
   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_TriggerWithError'       , @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='Test [TSTCheckTransactionErrors].[dbo].[SQLTest_TriggerWithError] passed. [A trigger will raise an error] Expected error was raised: Error number: 50000 Procedure: ''TR_TestTableTRG1_NoTransactions'' Message: Test error'
   EXEC dbo.ValidateLogEntryCountForSproc       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_TriggerWithError'       , @ExpectedLogEntryCount=3

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where a trigger raises an expected error but
-- where we have a teardown as well. Because the teardown cannot be 
-- executed inside a transaction the test fails.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TriggerWithErrorAndTeardown
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTransactionErrors'          ,
      @TestName            = 'SQLTest_SuiteTriggerWithErrorAndTeardown#Test' ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='SuiteTriggerWithErrorAndTeardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName=NULL                                                 , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_SuiteTriggerWithErrorAndTeardown'  , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SuiteTriggerWithErrorAndTeardown#Test'      , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteTriggerWithErrorAndTeardown#Test'       , @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SuiteTriggerWithErrorAndTeardown#Test'
   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteTriggerWithErrorAndTeardown#Test'       , @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='The transaction is in an uncommitable state after the test procedure ''[TSTCheckTransactionErrors].[dbo].[SQLTest_SuiteTriggerWithErrorAndTeardown#Test]'' has failed. A rollback was forced. The TEARDOWN will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteTriggerWithErrorAndTeardown#Test'       , @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_SuiteTriggerWithErrorAndTeardown'
   EXEC dbo.ValidateLogEntryCountForSproc       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteTriggerWithErrorAndTeardown#Test'       , @ExpectedLogEntryCount=3

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where a trigger raises an expected error but
-- where we have a teardown as well. The auto-rollback 
-- is disabled to prevent the scenario where the transaction reaches an 
-- uncommittable state.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_TriggerWithErrorNoRollback
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTransactionErrors'          ,
      @TestName            = 'SQLTest_SuiteTriggerWithErrorNoRollback#Test' ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='SuiteTriggerWithErrorNoRollback'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName=NULL                                                 , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_SuiteTriggerWithErrorNoRollback'   , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SuiteTriggerWithErrorNoRollback#Test'       , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteTriggerWithErrorNoRollback#Test'       , @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SuiteTriggerWithErrorNoRollback#Test'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteTriggerWithErrorNoRollback#Test'       , @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='Test [TSTCheckTransactionErrors].[dbo].[SQLTest_SuiteTriggerWithErrorNoRollback#Test] passed. [A trigger will raise an error] Expected error was raised: Error number: 50000 Procedure: ''TR_TestTableTRG1_NoTransactions'' Message: Test error'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteTriggerWithErrorNoRollback#Test'       , @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_SuiteTriggerWithErrorNoRollback. Row count in TestTableTRG1%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteTriggerWithErrorNoRollback#Test'       , @LogIndex=4, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert in SQLTest_TEARDOWN_SuiteTriggerWithErrorNoRollback. Row count in TriggerLog%'
   
   EXEC dbo.ValidateLogEntryCountForSproc       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteTriggerWithErrorNoRollback#Test'       , @ExpectedLogEntryCount=4

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where a transaction is placed in an invalid state
-- and an expected error is raised.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_PlaceTranInvalidState
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTransactionErrors'    ,
      @TestName            = 'SQLTest_Proc_Test_PlaceTranInvalidState'  ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                             @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                          @TestSessionId=@TestSessionId
   EXEC dbo.ValidateTestButNoSuiteSetupTeardownRecorded     @TestSessionId=@TestSessionId, @SProcName='SQLTest_Proc_Test_PlaceTranInvalidState'

   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_PlaceTranInvalidState'       , @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Proc_Test_PlaceTranInvalidState'
   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_PlaceTranInvalidState'       , @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='The transaction is in an uncommitable state after the test procedure ''[TSTCheckTransactionErrors].[dbo].[SQLTest_Proc_Test_PlaceTranInvalidState]'' has failed. A rollback was forced but the test will complete.'
   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_PlaceTranInvalidState'       , @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='Test [TSTCheckTransactionErrors].[dbo].[SQLTest_Proc_Test_PlaceTranInvalidState] passed. [An invalid cast will raise an error] Expected error was raised: Error number: 245 Procedure: ''PlaceTranInvalidState'' Message: N/A'
   EXEC dbo.ValidateLogEntryCountForSproc       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Proc_Test_PlaceTranInvalidState'       , @ExpectedLogEntryCount=3

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where a transaction is placed in an invalid state
-- and an expected error is raised. However a teardown is defined. 
-- Because the teardown cannot be executed inside a transaction the test fails.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_PlaceTranInvalidStateAndTeardown
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTransactionErrors'    ,
      @TestName            = 'SQLTest_SuiteInvalidTran#Test'  ,
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='SuiteInvalidTran'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName=NULL                                 , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_SuiteInvalidTran'  , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SuiteInvalidTran#Test'      , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteInvalidTran#Test'       , @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SuiteInvalidTran#Test'
   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteInvalidTran#Test'       , @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='The transaction is in an uncommitable state after the test procedure ''[TSTCheckTransactionErrors].[dbo].[SQLTest_SuiteInvalidTran#Test]'' has failed. A rollback was forced. The TEARDOWN will be executed outside of a transaction scope.'
   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteInvalidTran#Test'       , @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_SuiteInvalidTran'   
   EXEC dbo.ValidateLogEntryCountForSproc       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteInvalidTran#Test'       , @ExpectedLogEntryCount=3

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where a transaction is placed in an invalid state
-- and an expected error is raised. A teardown is defined. 
-- Auto-rollback is disabled.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_PlaceTranInvalidStateNoRollback
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckTransactionErrors'    ,
      @TestName            = 'SQLTest_SuiteInvalidTranNoRollback#Test',
      @ResultsFormat       = 'None'                      ,
      @CleanTemporaryData  = 0                           ,
      @TestSessionId       = @TestSessionId OUT          ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='SuiteInvalidTranNoRollback'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName=NULL                                            , @SProcType='Setup'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_TEARDOWN_SuiteInvalidTranNoRollback'   , @SProcType='Teardown'
   EXEC dbo.ValidateOnlyOneSProcExists             @TestSessionId=@TestSessionId, @SProcName='SQLTest_SuiteInvalidTranNoRollback#Test'       , @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteInvalidTranNoRollback#Test'       , @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SuiteInvalidTranNoRollback#Test'
   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteInvalidTranNoRollback#Test'       , @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='Test [TSTCheckTransactionErrors].[dbo].[SQLTest_SuiteInvalidTranNoRollback#Test] passed. [An invalid cast will raise an error] Expected error was raised: Error number: 245 Procedure: ''PlaceTranInvalidState'' Message: N/A'
   EXEC dbo.ValidateLogEntryForSprocByIndex     @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteInvalidTranNoRollback#Test'       , @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_SuiteInvalidTranNoRollback'   
   EXEC dbo.ValidateLogEntryCountForSproc       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SuiteInvalidTranNoRollback#Test'       , @ExpectedLogEntryCount=3

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- END testing the Transaction Errors scenarios
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- START testing the custom test prefix
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

CREATE PROCEDURE SQLTest_TEARDOWN_Prefix
AS
BEGIN
   DELETE FROM TSTCheckCustomPrefix.dbo.TestParameters
   DELETE FROM TST.Data.TSTVariables
END
GO

CREATE PROCEDURE dbo.CustomPrefixCommonValidation
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   EXEC TST.Runner.RunAll
      @TestDatabaseName    = 'TSTCheckCustomPrefix'   ,
      @ResultsFormat       = 'None'                   ,
      @CleanTemporaryData  = 0                        ,
      @TestSessionId       = @TestSessionId OUT       ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession              @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors           @TestSessionId=@TestSessionId

   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='ST_SESSION_SETUP'     , @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is ST_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc          @TestSessionId=@TestSessionId,  @SProcName='ST_SESSION_SETUP'     , @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='ST_Suite1#TestA'      , @LogIndex=1, @ExpectedLogType='P', @ExpectedLogMessage='%Test @@TRANCOUNT in ST_SETUP_Suite1%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='ST_Suite1#TestA'      , @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test @@TRANCOUNT in ST_Suite1#TestA%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='ST_Suite1#TestA'      , @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Test @@TRANCOUNT in ST_TEARDOWN_Suite1%'
   EXEC dbo.ValidateLogEntryCountForSproc          @TestSessionId=@TestSessionId,  @SProcName='ST_Suite1#TestA'      , @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='ST_Suite1#TestB'      , @LogIndex=1, @ExpectedLogType='P', @ExpectedLogMessage='%Test @@TRANCOUNT in ST_SETUP_Suite1%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='ST_Suite1#TestB'      , @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test @@TRANCOUNT in ST_Suite1#TestB%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='ST_Suite1#TestB'      , @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Test @@TRANCOUNT in ST_TEARDOWN_Suite1%'
   EXEC dbo.ValidateLogEntryCountForSproc          @TestSessionId=@TestSessionId,  @SProcName='ST_Suite1#TestB'      , @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='ST_Suite2#TestA'      , @LogIndex=1, @ExpectedLogType='P', @ExpectedLogMessage='%Test @@TRANCOUNT in ST_SETUP_Suite2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='ST_Suite2#TestA'      , @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test @@TRANCOUNT in ST_Suite2#TestA%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='ST_Suite2#TestA'      , @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Test @@TRANCOUNT in ST_TEARDOWN_Suite2%'
   EXEC dbo.ValidateLogEntryCountForSproc          @TestSessionId=@TestSessionId,  @SProcName='ST_Suite2#TestA'      , @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='ST_Suite2#TestB'      , @LogIndex=1, @ExpectedLogType='P', @ExpectedLogMessage='%Test @@TRANCOUNT in ST_SETUP_Suite2%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='ST_Suite2#TestB'      , @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Test @@TRANCOUNT in ST_Suite2#TestB%'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='ST_Suite2#TestB'      , @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Test @@TRANCOUNT in ST_TEARDOWN_Suite2%'
   EXEC dbo.ValidateLogEntryCountForSproc          @TestSessionId=@TestSessionId,  @SProcName='ST_Suite2#TestB'      , @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='ST_TestEqualsFails'   , @LogIndex=1, @ExpectedLogType='F', @ExpectedLogMessage='%Test Assert.Equals in ST_TestEqualsFails%'
   EXEC dbo.ValidateLogEntryCountForSproc          @TestSessionId=@TestSessionId,  @SProcName='ST_TestEqualsFails'   , @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='ST_TestEqualsOK'      , @LogIndex=1, @ExpectedLogType='P', @ExpectedLogMessage='%Test Assert.Equals in ST_TestEqualsOK%'
   EXEC dbo.ValidateLogEntryCountForSproc          @TestSessionId=@TestSessionId,  @SProcName='ST_TestEqualsOK'      , @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='ST_SESSION_TEARDOWN'  , @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is ST_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc          @TestSessionId=@TestSessionId,  @SProcName='ST_SESSION_TEARDOWN'  , @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryCountForTestSession @TestSessionId=@TestSessionId,  @ExpectedLogEntryCount=16

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Testing the case where the sql prefix is set to 
-- something else than the default.
-- Relies on the custom prefix being set at global level by dbo.TSTConfig.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Prefix#CustomPrefix1
AS
BEGIN

   INSERT INTO TSTCheckCustomPrefix.dbo.TestParameters (PrefixDatabaseName, CustomPrefix) VALUES (NULL, 'ST_')
   INSERT INTO TSTCheckCustomPrefix.dbo.TestParameters (PrefixDatabaseName, CustomPrefix) VALUES ('OtherDatabase', 'OtherPrefix_')
   
   EXEC dbo.CustomPrefixCommonValidation

END
GO

-- =======================================================================
-- Testing the case where the sql prefix is set to 
-- something else than the default.
-- Relies on the custom prefix being set at database level in dbo.TSTConfig.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Prefix#CustomPrefix2
AS
BEGIN

   INSERT INTO TSTCheckCustomPrefix.dbo.TestParameters (PrefixDatabaseName, CustomPrefix) VALUES (NULL, 'OtherPrefix_')
   INSERT INTO TSTCheckCustomPrefix.dbo.TestParameters (PrefixDatabaseName, CustomPrefix) VALUES ('TSTCheckCustomPrefix', 'ST_')
   
   EXEC dbo.CustomPrefixCommonValidation

END
GO

-- =======================================================================
-- Testing the case where the sql prefix is set to 
-- something else than the default.
-- Relies on the custom prefix being set by a call to 
-- outside of (before) the test session TST.Utils.SetTSTVariable.
-- The custom prefix is set at global level.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Prefix#CustomPrefix3
AS
BEGIN

   EXEC TST.Utils.SetTSTVariable NULL,             'SqlTestPrefix', 'ST_'
   EXEC TST.Utils.SetTSTVariable 'OtherDatabase',  'SqlTestPrefix', 'OtherPrefix_'
   
   EXEC dbo.CustomPrefixCommonValidation

END
GO

-- =======================================================================
-- Testing the case where the sql prefix is set to 
-- something else than the default.
-- Relies on the custom prefix being set by a call to 
-- outside of (before) the test session TST.Utils.SetTSTVariable.
-- The custom prefix is set at database level.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Prefix#CustomPrefix4
AS
BEGIN

   EXEC TST.Utils.SetTSTVariable    NULL,                   'SqlTestPrefix', 'OtherPrefix_'
   EXEC TST.Utils.SetTSTVariable    'TSTCheckCustomPrefix', 'SqlTestPrefix', 'ST_'
   
   EXEC dbo.CustomPrefixCommonValidation

END
GO

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- END testing the custom test prefix
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- START testing the Assert.Ignore
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

CREATE PROCEDURE SQLTest_SETUP_Ignore
AS
BEGIN
   DELETE FROM TSTCheckIgnore.dbo.TestParameters
END
GO

CREATE PROCEDURE SQLTest_TEARDOWN_Ignore
AS
BEGIN
   DELETE FROM TSTCheckIgnore.dbo.TestParameters
END
GO

-- =======================================================================
-- Test the case of one simple test procedure that starts with an Assert.Ignore
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Ignore#SimpleIgnore
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckIgnore'      ,
      @TestName            = 'SQLTest_Test1'       ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateNoSystemErrors                          @TestSessionId=@TestSessionId
   EXEC dbo.ValidateTestButNoSuiteSetupTeardownRecorded     @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test1'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @LogIndex=1, @ExpectedLogType='I', @ExpectedLogMessage='Ignore SQLTest_Test1'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1', @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case of one simple test procedure that 
-- contains an Assert.Ignore in the middle.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Ignore#IgnoreInMiddle
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckIgnore'      ,
      @TestName            = 'SQLTest_Test2'       ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateNoSystemErrors                          @TestSessionId=@TestSessionId
   EXEC dbo.ValidateTestButNoSuiteSetupTeardownRecorded     @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test2'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test2', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Test2'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test2', @LogIndex=2, @ExpectedLogType='P', @ExpectedLogMessage='%Passing Assert.Equals in SQLTest_Test2%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test2', @LogIndex=3, @ExpectedLogType='I', @ExpectedLogMessage='Ignore SQLTest_Test2'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test2', @ExpectedLogEntryCount=3

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case of one test procedure that is part of a suite. 
-- The test procedure starts with an Assert.Ignore.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Ignore#SuiteTestIgnore1
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckIgnore'      ,
      @TestName            = 'SQLTest_Suite1#TestA',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite1'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Suite1#TestA', @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite1'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestA', @LogIndex=2, @ExpectedLogType='I', @ExpectedLogMessage='Ignore SQLTest_Suite1#TestA'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestA', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite1'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestA', @ExpectedLogEntryCount=3

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case of one test procedure that is part of a suite. 
-- The test procedure has an Assert.Ignore in the middle.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Ignore#SuiteTestIgnore2
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckIgnore'      ,
      @TestName            = 'SQLTest_Suite1#TestB',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite1'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Suite1#TestB', @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite1'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite1#TestB'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Passing Assert.Equals in SQLTest_Suite1#TestB%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @LogIndex=4, @ExpectedLogType='I', @ExpectedLogMessage='Ignore SQLTest_Suite1#TestB'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @LogIndex=5, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite1'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @ExpectedLogEntryCount=5

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case of one test procedure that is part of a suite. 
-- The test procedure has an Assert.Ignore but that is after a failure.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Ignore#SuiteTestIgnore3
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckIgnore'      ,
      @TestName            = 'SQLTest_Suite1#TestC',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite1'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Suite1#TestC', @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestC', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite1'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestC', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite1#TestC'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestC', @LogIndex=3, @ExpectedLogType='F', @ExpectedLogMessage='%Test failing Assert.Equals in SQLTest_Suite1#TestC%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestC', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite1'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestC', @ExpectedLogEntryCount=4

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Test the case of one suite that has several tests 
-- each containing an Assert.Ignore.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Ignore#SuiteTestIgnore4
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckIgnore'      ,
      @SuiteName           = 'Suite1'              ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite1'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Suite1#TestA,SQLTest_Suite1#TestB,SQLTest_Suite1#TestC', @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite1'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestA', @LogIndex=2, @ExpectedLogType='I', @ExpectedLogMessage='Ignore SQLTest_Suite1#TestA'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestA', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite1'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestA', @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite1'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite1#TestB'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Passing Assert.Equals in SQLTest_Suite1#TestB%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @LogIndex=4, @ExpectedLogType='I', @ExpectedLogMessage='Ignore SQLTest_Suite1#TestB'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @LogIndex=5, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite1'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestB', @ExpectedLogEntryCount=5

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestC', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite1'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestC', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite1#TestC'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex   @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestC', @LogIndex=3, @ExpectedLogType='F', @ExpectedLogMessage='%Test failing Assert.Equals in SQLTest_Suite1#TestC%'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestC', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite1'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite1#TestC', @ExpectedLogEntryCount=4

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Test the case of one test procedure that is part of a suite.
-- The suite setup procedure contains an Assert.Ignore.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Ignore#SuiteIgnore1
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckIgnore'      ,
      @TestName            = 'SQLTest_Suite2#TestA',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite2'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Suite2#TestA', @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite2'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestA', @LogIndex=2, @ExpectedLogType='I', @ExpectedLogMessage='Ignore Suite2. The entire suite will be ignored.'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestA', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite2'
   EXEC dbo.ValidateLogEntryCountForSproc          @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestA', @ExpectedLogEntryCount=3

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case of one suite that has several tests.
-- The suite setup procedure contains an Assert.Ignore.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Ignore#SuiteIgnore2
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckIgnore'      ,
      @SuiteName           = 'Suite2'              ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have passed', 1, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite2'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Suite2#TestA,SQLTest_Suite2#TestB', @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite2'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestA', @LogIndex=2, @ExpectedLogType='I', @ExpectedLogMessage='Ignore Suite2. The entire suite will be ignored.'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestA', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite2'
   EXEC dbo.ValidateLogEntryCountForSproc          @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestA', @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite2'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestB', @LogIndex=2, @ExpectedLogType='I', @ExpectedLogMessage='Ignore Suite2. The entire suite will be ignored.'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestB', @LogIndex=3, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite2'
   EXEC dbo.ValidateLogEntryCountForSproc          @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite2#TestB', @ExpectedLogEntryCount=3

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Test the case of one test procedure that is part of a suite.
-- The suite teardown procedure contains an Assert.Ignore.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Ignore#TeardownIgnore1
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 
   
   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckIgnore'      ,
      @TestName            = 'SQLTest_Suite3#TestA',
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite3'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Suite3#TestA', @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite3'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite3#TestA'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Passing Assert.Equals in SQLTest_Suite3#TestA%'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite3'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=5, @ExpectedLogType='E', @ExpectedLogMessage='A teardown procedure cannot invoke Assert.Ignore. The Assert.Ignore can only be invoked by a suite setup or by a test procedure.'
   EXEC dbo.ValidateLogEntryCountForSproc          @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @ExpectedLogEntryCount=5

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case of one suite that has several tests.
-- The suite teardown procedure contains an Assert.Ignore.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Ignore#TeardownIgnore2
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit
   
   EXEC TST.Runner.RunSuite
      @TestDatabaseName    = 'TSTCheckIgnore'      ,
      @SuiteName           = 'Suite3'              ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateTestSession                    @TestSessionId=@TestSessionId
   EXEC dbo.ValidateNoSystemErrors                 @TestSessionId=@TestSessionId
   EXEC dbo.ValidateOnlyOneSuiteExists             @TestSessionId=@TestSessionId, @SuiteName='Suite3'
   EXEC dbo.ValidateOnlyGivenTestExistsByType      @TestSessionId=@TestSessionId, @SProcsNames='SQLTest_Suite3#TestA,SQLTest_Suite3#TestB', @SProcType='Test'

   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite3'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite3#TestA'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=3, @ExpectedLogType='P', @ExpectedLogMessage='%Passing Assert.Equals in SQLTest_Suite3#TestA%'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite3'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @LogIndex=5, @ExpectedLogType='E', @ExpectedLogMessage='A teardown procedure cannot invoke Assert.Ignore. The Assert.Ignore can only be invoked by a suite setup or by a test procedure.'
   EXEC dbo.ValidateLogEntryCountForSproc          @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestA', @ExpectedLogEntryCount=5

   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestB', @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SETUP_Suite3'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestB', @LogIndex=2, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_Suite3#TestB'
   EXEC dbo.ValidateLogEntryLikeForSprocByIndex    @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestB', @LogIndex=3, @ExpectedLogType='F', @ExpectedLogMessage='%Failing Assert.Equals in SQLTest_Suite3#TestB%'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestB', @LogIndex=4, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_TEARDOWN_Suite3'
   EXEC dbo.ValidateLogEntryForSprocByIndex        @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestB', @LogIndex=5, @ExpectedLogType='E', @ExpectedLogMessage='A teardown procedure cannot invoke Assert.Ignore. The Assert.Ignore can only be invoked by a suite setup or by a test procedure.'
   EXEC dbo.ValidateLogEntryCountForSproc          @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Suite3#TestB', @ExpectedLogEntryCount=5

   EXEC TST.Internal.CleanSessionData @TestSessionId

END
GO

-- =======================================================================
-- Test the case of one simple test procedure when
-- the session setup procedure contains an Assert.Ignore.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Ignore#IgnoreInSessionSetup
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   INSERT INTO TSTCheckIgnore.dbo.TestParameters (ParameterValue) VALUES ('S')

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckIgnore'      ,
      @TestName            = 'SQLTest_Test1'       ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateNoSystemErrors                          @TestSessionId=@TestSessionId
   EXEC dbo.ValidateTestButNoSuiteSetupTeardownRecorded     @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test1'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP',      @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP',      @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='The test session setup procedure cannot invoke Assert.Ignore. The Assert.Ignore can only be invoked by a suite setup or by a test procedure.'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP',      @LogIndex=3, @ExpectedLogType='E', @ExpectedLogMessage='The test session will be aborted. No tests will be run. The execution will continue with the test session teardown.'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP',      @ExpectedLogEntryCount=3

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN',   @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN',   @ExpectedLogEntryCount=1

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- =======================================================================
-- Test the case of one simple test procedure when
-- the session teardown procedure contains an Assert.Ignore.
-- =======================================================================
CREATE PROCEDURE dbo.SQLTest_Ignore#IgnoreInSessionTeardown
AS
BEGIN

   DECLARE @TestSessionId        int
   DECLARE @TestSessionPassed    bit 

   INSERT INTO TSTCheckIgnore.dbo.TestParameters (ParameterValue) VALUES ('T')

   EXEC TST.Runner.RunTest
      @TestDatabaseName    = 'TSTCheckIgnore'      ,
      @TestName            = 'SQLTest_Test1'       ,
      @ResultsFormat       = 'None'                ,
      @CleanTemporaryData  = 0                     ,
      @TestSessionId       = @TestSessionId OUT    ,
      @TestSessionPassed   = @TestSessionPassed OUT

   EXEC TST.Assert.Equals 'The test session must have failed', 0, @TestSessionPassed

   EXEC dbo.ValidateNoSystemErrors                          @TestSessionId=@TestSessionId
   EXEC dbo.ValidateTestButNoSuiteSetupTeardownRecorded     @TestSessionId=@TestSessionId, @SProcName='SQLTest_Test1'

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP',      @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_SETUP'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_SETUP',      @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1',              @LogIndex=1, @ExpectedLogType='I', @ExpectedLogMessage='Ignore SQLTest_Test1'
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_Test1',              @ExpectedLogEntryCount=1

   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN',   @LogIndex=1, @ExpectedLogType='L', @ExpectedLogMessage='This is SQLTest_SESSION_TEARDOWN'
   EXEC dbo.ValidateLogEntryForSprocByIndex       @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN',   @LogIndex=2, @ExpectedLogType='E', @ExpectedLogMessage='The test session teardown procedure cannot invoke Assert.Ignore. The Assert.Ignore can only be invoked by a suite setup or by a test procedure.'
   
   EXEC dbo.ValidateLogEntryCountForSproc         @TestSessionId=@TestSessionId,  @SProcName='SQLTest_SESSION_TEARDOWN',   @ExpectedLogEntryCount=2

   EXEC TST.Internal.CleanSessionData @TestSessionId
   
END
GO

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-- END testing the Assert.Ignore
-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

USE tempdb
GO

