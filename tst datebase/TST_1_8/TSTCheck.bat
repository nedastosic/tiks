@ECHO OFF
IF "%useverbose%"=="1" ECHO ON
REM ===================================================
REM This is the TST validation script
REM For help run TSTCheck.bat /?
REM ===================================================
SETLOCAL

REM Setting up variables
SET TC_ExitCode=0
SET TC_SqlOutput="%Temp%\TC_SqlOutput.txt"
SET TC_CommandOutput="%Temp%\TC_CmdOutput.txt"
SET TC_PathToScriptFolder=%~dp0
SET TC_SqlCmdParameters=-S localhost -E -b

REM Process the input parameters
IF /I "%1"=="/?" (CALL :SubHelpPage & SET TC_ParametersExitCode=0& GOTO LblExit)
IF /I NOT "%1"=="" (
   ECHO Invalid command line parameters. The only valid parameter is /?.>&2
   GOTO :LblFatalError
)

REM Preparatory steps
CALL :SubSetupSupportDatabases   & IF ERRORLEVEL 1 (GOTO LblFatalError)

REM Running actual validations
CALL :SubRunUnitTestsOnTST & IF ERRORLEVEL 1 (GOTO LblFatalError)
CALL :SubValidateTSTBatch  & IF ERRORLEVEL 1 (GOTO LblFatalError)
:LblDone

CALL :SubDropSupportDatabases
IF ERRORLEVEL 1 (
   ECHO.
   ECHO Warning: Dropping some test databases failed.>&2
   SET TC_ExitCode=1
)

ECHO.
ECHO ==================================================================
ECHO.
IF "%TC_ExitCode%" == "0" (ECHO TSTCheck Status: All Tests Passed) ELSE (ECHO TSTCheck Status: Failure>&2)

:LblExit
EXIT /B %TC_ExitCode%
ENDLOCAL
GOTO :EOF

:LblFatalError
SET TC_ExitCode=1
GOTO LblDone


REM ==============================================================
REM Sets up the support databases neded to self check TST.
REM Return code: 
REM   0 - OK
REM   1 - An error occured. An error message was already displayed.
REM ==============================================================
:SubSetupSupportDatabases
SET TC_SetupSupportDBExitCode=0

REM Make sure that the current version of TST database is set-up.
ECHO.
CALL "%TC_PathToScriptFolder%TST.bat" /Force
IF ERRORLEVEL 1 (
   ECHO Error setting up the TST database.>&2
   SET TC_SetupSupportDBExitCode=1
   GOTO LblSupportDBDone
)

ECHO.
ECHO ===================== Prepare Test Databases =====================
ECHO.

REM make sure that TST.bat /QuickStart works fine
CALL "%TC_PathToScriptFolder%TST.bat" /QuickStart > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO TST.BAT /QuickStart failed.>&2
   TYPE %TC_SqlOutput% >&2
   SET TC_SetupSupportDBExitCode=1
   GOTO LblSupportDBDone
)

ECHO TST.BAT /QuickStart completed successfuly.

CALL :SubCreateDatabase TSTCheckSimple                   & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckSessionLevelOutput       & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckIgnore                   & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheck                         & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckTran                     & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckTransactionErrors        & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckTable                    & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckError                    & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckNoTests                  & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckSchema                   & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckTableEmptyOrNot          & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckCustomPrefix             & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckTestSession              & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckTestSession2             & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckTestSessionErr           & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckView_TSTResultsEx        & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)
CALL :SubCreateDatabase TSTCheckMaster                   & IF ERRORLEVEL 1 (SET TC_SetupSupportDBExitCode=1& GOTO LblSupportDBDone)

:LblSupportDBDone
EXIT /B %TC_SetupSupportDBExitCode%
GOTO :EOF

REM ==============================================================
REM This subroutine run the SQL script used to create a given database
REM Return code:
REM   0 - OK
REM   1 - An error occured. An error message was already displayed.
REM ==============================================================
:SubCreateDatabase

SET TC_CreateDBName=%~1
SET TC_CreateDBExitCode=0

sqlcmd %TC_SqlCmdParameters% -i "%TC_PathToScriptFolder%Test\Set%TC_CreateDBName%.sql" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error setting up the %TC_CreateDBName% database.>&2
   TYPE %TC_SqlOutput% >&2
   SET TC_CreateDBExitCode=1
   GOTO LblCreateDBDone
)
ECHO Database %TC_CreateDBName% was successfuly set-up.

:LblCreateDBDone
EXIT /B %TC_CreateDBExitCode%
GOTO :EOF

REM ==============================================================
REM This subroutine will drop all the support databases that were created
REM Return code:
REM   0 - OK
REM   1 - An error occured. An error message was already displayed.
REM ==============================================================
:SubDropSupportDatabases

SET TC_DropSupportDBExitCode=0

ECHO.
ECHO ===================== Drop Test Databases ========================
ECHO.

CALL :SubDropDatabase TSTCheckSimple               & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckSessionLevelOutput   & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckIgnore               & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheck                     & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTran                 & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTransactionErrors    & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTable                & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckError                & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckNoTests              & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckSchema               & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTableEmptyOrNot      & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckCustomPrefix         & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTestSession          & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTestSession2         & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTestSessionErr0      & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTestSessionErr1      & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTestSessionErr2      & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTestSessionErr3      & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTestSessionErr4      & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTestSessionErr5      & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTestSessionErr6      & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTestSessionErr7      & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckTestSessionErr8      & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckView_TSTResultsEx    & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTCheckMaster               & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)
CALL :SubDropDatabase TSTQuickStart                & IF ERRORLEVEL 1 (SET TC_DropSupportDBExitCode=1)

EXIT /B %TC_DropSupportDBExitCode%
GOTO :EOF

REM ==============================================================
REM This subroutine will drop a given database.
REM Return code:
REM   0 - OK
REM   1 - An error occured. An error message was already displayed.
REM ==============================================================
:SubDropDatabase

SET TC_DropDatabaseName=%~1
SET TC_DropDBExitCode=0

sqlcmd %TC_SqlCmdParameters% -Q "EXIT (SELECT COUNT([name]) FROM sys.databases WHERE [name] = '%TC_DropDatabaseName%')" > %TC_SqlOutput% 2>&1
IF "%ERRORLEVEL%"=="0" GOTO LblDropDBDone

sqlcmd %TC_SqlCmdParameters% -Q "DROP DATABASE [%TC_DropDatabaseName%]" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO WARNING: Error dropping the database %TC_DropDatabaseName%.>&2
   TYPE %TC_SqlOutput% >&2
   SET TC_DropDBExitCode=1
   GOTO LblDropDBDone
) 
ECHO Database %TC_DropDatabaseName% dropped.

:LblDropDBDone
EXIT /B %TC_DropDBExitCode%
GOTO :EOF


REM ==============================================================
REM This subroutine executes the TST tests contained in 
REM the TSTCheckMaster database. This will self test the featurs 
REM in the TST database.
REM Return code: 
REM   0 - OK
REM   1 - An error or test failure occured. 
REM       An error message was already displayed.
REM ==============================================================
:SubRunUnitTestsOnTST

SET TC_UnitTestsExitCode=0
ECHO.
ECHO ===================== Execute the TST tests in TSTCheckMaster ====
ECHO.

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckMaster
IF ERRORLEVEL 1 (
   SET TC_UnitTestsExitCode=1
   GOTO LblUnitTestsDone
)

:LblUnitTestsDone
EXIT /B %TC_UnitTestsExitCode%
GOTO :EOF

REM ==============================================================
REM This subroutine invokes TST.bat and compares its output 
REM against a baseline.
REM Return code: 
REM   0 - OK
REM   1 - An error or test failure occured. 
REM       An error message was already displayed.
REM ==============================================================
:SubValidateTSTBatch

SET TC_BatchTestsExitCode=0

ECHO.
ECHO ===================== Validate TST.BAT script output =============
ECHO.

CALL "%TC_PathToScriptFolder%TST.bat" /Help >%TC_CommandOutput% 2>&1
CALL :SubValidateAgainstBaseline "Help Page" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\HelpPage.txt"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTQuickStart /NoTimestamp >%TC_CommandOutput% 2>&1
CALL :SubValidateAgainstBaseline "Running tests in TSTQuickStart" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\QuickStart.txt"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSimple /NoTimestamp >%TC_CommandOutput% 2>&1
CALL :SubValidateAgainstBaseline "Simple Test Scenario" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SimpleDb.txt"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSimple /NoTimestamp /Verbose >%TC_CommandOutput% 2>&1
CALL :SubValidateAgainstBaseline "Simple Test Scenario Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SimpleDbVerbose.txt"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSimple /NoTimestamp /Verbose /XmlFormat %TC_CommandOutput% >nul 2>&1
CALL :SubValidateAgainstBaseline "Simple Test Scenario Xml Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SimpleDbVerbose.xml"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

REM ===================================================
REM START Section: validating the output when session 
REM                level setup/teardown are present.
REM ===================================================

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSessionLevelOutput /NoTimestamp >%TC_CommandOutput% 2>&1
CALL :SubValidateAgainstBaseline "Session Level Output Test Scenario" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionLevelOutput.txt"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSessionLevelOutput /NoTimestamp /Verbose >%TC_CommandOutput% 2>&1
CALL :SubValidateAgainstBaseline "Session Level Output Test Scenario Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionLevelOutputVerbose.txt"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSessionLevelOutput /NoTimestamp /Verbose /XmlFormat %TC_CommandOutput% >nul 2>&1
CALL :SubValidateAgainstBaseline "Session Level Output Test Scenario Xml Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionLevelOutputVerbose.xml"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

sqlcmd %TC_SqlCmdParameters% -d TST -Q "DELETE TSTCheckSessionLevelOutput.dbo.TestParameters" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (With Failure in Setup) Test Scenario". Step #1.>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)

sqlcmd %TC_SqlCmdParameters% -d TST -Q "INSERT INTO TSTCheckSessionLevelOutput.dbo.TestParameters(ParameterValue) VALUES ('Failure in session setup')" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (With Failure in Setup) Test Scenario". Step #2.>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSessionLevelOutput /NoTimestamp /Verbose >%TC_CommandOutput% 2>&1
CALL :SubValidateAgainstBaseline "Session Setup Failure Output Test Scenario Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionSetupFailureOutputVerbose.txt"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSessionLevelOutput /NoTimestamp /Verbose /XmlFormat %TC_CommandOutput% >nul 2>&1
CALL :SubValidateAgainstBaseline "Session Setup Failure Output Test Scenario Xml Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionSetupFailureOutputVerbose.xml"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

sqlcmd %TC_SqlCmdParameters% -d TST -Q "DELETE TSTCheckSessionLevelOutput.dbo.TestParameters" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (Passing Test and Failure in Teardown) Test Scenario". Step #1.>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)

sqlcmd %TC_SqlCmdParameters% -d TST -Q "INSERT INTO TSTCheckSessionLevelOutput.dbo.TestParameters(ParameterValue) VALUES ('Failure in session teardown')" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (Passing Test and Failure in Teardown) Test Scenario". Step #2.>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)

CALL "%TC_PathToScriptFolder%TST.bat" /RunTest TSTCheckSessionLevelOutput SQLTest_Suite1#TestA /NoTimestamp /Verbose >%TC_CommandOutput% 2>&1
CALL :SubValidateAgainstBaseline "Session Teardown Only Failure Output Test Scenario Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionOnlyTeardownFailureOutputVerbose.txt"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

CALL "%TC_PathToScriptFolder%TST.bat" /RunTest TSTCheckSessionLevelOutput SQLTest_Suite1#TestA /NoTimestamp /Verbose /XmlFormat %TC_CommandOutput% >nul 2>&1
CALL :SubValidateAgainstBaseline "Session Teardown Only Failure Output Test Scenario Xml Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionOnlyTeardownFailureOutputVerbose.xml"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)


sqlcmd %TC_SqlCmdParameters% -d TST -Q "DELETE TSTCheckSessionLevelOutput.dbo.TestParameters" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (With Failure in Teardown) Test Scenario". Step #1.>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)

sqlcmd %TC_SqlCmdParameters% -d TST -Q "INSERT INTO TSTCheckSessionLevelOutput.dbo.TestParameters(ParameterValue) VALUES ('Failure in session teardown')" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (With Failure in Teardown) Test Scenario". Step #2.>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSessionLevelOutput /NoTimestamp /Verbose >%TC_CommandOutput% 2>&1
CALL :SubValidateAgainstBaseline "Session Teardown Failure Output Test Scenario Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionTeardownFailureOutputVerbose.txt"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSessionLevelOutput /NoTimestamp /Verbose /XmlFormat %TC_CommandOutput% >nul 2>&1
CALL :SubValidateAgainstBaseline "Session Teardown Failure Output Test Scenario Xml Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionTeardownFailureOutputVerbose.xml"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

sqlcmd %TC_SqlCmdParameters% -d TST -Q "DELETE TSTCheckSessionLevelOutput.dbo.TestParameters" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (With Failure) Test Scenario". Step #1>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)

sqlcmd %TC_SqlCmdParameters% -d TST -Q "INSERT INTO TSTCheckSessionLevelOutput.dbo.TestParameters(ParameterValue) VALUES ('Failure in session setup')" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (With Failure) Test Scenario". Step #2>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)
sqlcmd %TC_SqlCmdParameters% -d TST -Q "INSERT INTO TSTCheckSessionLevelOutput.dbo.TestParameters(ParameterValue) VALUES ('Failure in session teardown')" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (With Failure) Test Scenario". Step #3>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSessionLevelOutput /NoTimestamp /Verbose >%TC_CommandOutput% 2>&1
CALL :SubValidateAgainstBaseline "Session Level Output Test Scenario [Failure] Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionLevelFailureOutputVerbose.txt"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSessionLevelOutput /NoTimestamp /Verbose /XmlFormat %TC_CommandOutput% >nul 2>&1
CALL :SubValidateAgainstBaseline "Session Level Output Test Scenario [Failure] Xml Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionLevelFailureOutputVerbose.xml"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

sqlcmd %TC_SqlCmdParameters% -d TST -Q "DELETE TSTCheckSessionLevelOutput.dbo.TestParameters" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (With Error) Test Scenario". Step #1>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)

sqlcmd %TC_SqlCmdParameters% -d TST -Q "INSERT INTO TSTCheckSessionLevelOutput.dbo.TestParameters(ParameterValue) VALUES ('Error in session setup')" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (With Error) Test Scenario". Step #2>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)
sqlcmd %TC_SqlCmdParameters% -d TST -Q "INSERT INTO TSTCheckSessionLevelOutput.dbo.TestParameters(ParameterValue) VALUES ('Error in session teardown')" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (With Error) Test Scenario". Step #3>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSessionLevelOutput /NoTimestamp /Verbose >%TC_CommandOutput% 2>&1
CALL :SubValidateAgainstBaseline "Session Level Output Test Scenario [Error] Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionLevelErrorOutputVerbose.txt"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSessionLevelOutput /NoTimestamp /Verbose /XmlFormat %TC_CommandOutput% >nul 2>&1
CALL :SubValidateAgainstBaseline "Session Level Output Test Scenario [Error] Xml Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionLevelErrorOutputVerbose.xml"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

sqlcmd %TC_SqlCmdParameters% -d TST -Q "DELETE TSTCheckSessionLevelOutput.dbo.TestParameters" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (With Ignore) Test Scenario". Step #1>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)

sqlcmd %TC_SqlCmdParameters% -d TST -Q "INSERT INTO TSTCheckSessionLevelOutput.dbo.TestParameters(ParameterValue) VALUES ('Ignore in session setup')" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (With Ignore) Test Scenario". Step #2>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)
sqlcmd %TC_SqlCmdParameters% -d TST -Q "INSERT INTO TSTCheckSessionLevelOutput.dbo.TestParameters(ParameterValue) VALUES ('Ignore in session teardown')" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error preparing the "Session Level Output (With Ignore) Test Scenario". Step #3>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblBatchTestsError
)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSessionLevelOutput /NoTimestamp /Verbose >%TC_CommandOutput% 2>&1
CALL :SubValidateAgainstBaseline "Session Level Output Test Scenario [Ignore] Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionLevelIgnoreOutputVerbose.txt"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

CALL "%TC_PathToScriptFolder%TST.bat" /RunAll TSTCheckSessionLevelOutput /NoTimestamp /Verbose /XmlFormat %TC_CommandOutput% >nul 2>&1
CALL :SubValidateAgainstBaseline "Session Level Output Test Scenario [Ignore] Xml Verbose" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\SessionLevelIgnoreOutputVerbose.xml"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

REM ===================================================
REM END Section: validating the output when session 
REM                level setup/teardown are present.
REM ===================================================

CALL "%TC_PathToScriptFolder%TEST\TSTErrorHandling.bat" %TC_CommandOutput%
CALL :SubValidateAgainstBaseline "Error Handling Scenarios" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\ErrorHandling.txt"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

CALL :SubPreserveTSTVariables %TC_CommandOutput%
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)
CALL :SubValidateAgainstBaseline "Test Preserving TST Variables" %TC_CommandOutput% "%TC_PathToScriptFolder%Test\Baseline\PreserveTSTVariables.txt"
IF ERRORLEVEL 1 (GOTO LblBatchTestsError)

GOTO LblBatchTestsDone

:LblBatchTestsError
SET TC_BatchTestsExitCode=1

:LblBatchTestsDone
EXIT /B %TC_BatchTestsExitCode%
GOTO :EOF

REM ==============================================================
REM Runs the commands we need in order to exercise the 
REM TST variables preservation during the setup.
REM ==============================================================
:SubPreserveTSTVariables

SET TC_PreserveTSTVariablesOutput="%~1"

SET TC_PreserveTSTVariablesExitCode=0

REM TST Setup should work when the table Data.TSTVariables does not exist (as is the case when we upgrade from V1.7 or earlier).
sqlcmd %TC_SqlCmdParameters% -d TST -Q "DROP TABLE Data.TSTVariables" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error testing preserving the TST Variables.>&2
   ECHO Error dropping table Data.TSTVariables.>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblPreserveTSTVariablesError
)

ECHO. >%TC_PreserveTSTVariablesOutput%
ECHO Setting TST in absence of the Data.TSTVariables table. >>%TC_PreserveTSTVariablesOutput%
ECHO. >>%TC_PreserveTSTVariablesOutput%

CALL "%TC_PathToScriptFolder%TST.bat" /Force >>%TC_PreserveTSTVariablesOutput%
IF ERRORLEVEL 1 (
   ECHO Error testing preserving the TST Variables.>&2
   ECHO Error setting up the TST database [phase 1].>&2
   GOTO LblPreserveTSTVariablesError
)

CALL "%TC_PathToScriptFolder%TST.bat" /Set DB1 SqlTestPrefix DB1_P1_ >>%TC_PreserveTSTVariablesOutput%
IF ERRORLEVEL 1 (ECHO Error setting a TST variable.>&2& GOTO LblPreserveTSTVariablesError)

CALL "%TC_PathToScriptFolder%TST.bat" /Set DB1 SqlTestPrefix DB1_P2_ >>%TC_PreserveTSTVariablesOutput%
IF ERRORLEVEL 1 (ECHO Error setting a TST variable.>&2& GOTO LblPreserveTSTVariablesError)

CALL "%TC_PathToScriptFolder%TST.bat" /Set DB2 SqlTestPrefix DB2_P1_ >>%TC_PreserveTSTVariablesOutput%
IF ERRORLEVEL 1 (ECHO Error setting a TST variable.>&2& GOTO LblPreserveTSTVariablesError)

CALL "%TC_PathToScriptFolder%TST.bat" /Set DB2 SqlTestPrefix DB2_P2_ >>%TC_PreserveTSTVariablesOutput%
IF ERRORLEVEL 1 (ECHO Error setting a TST variable.>&2& GOTO LblPreserveTSTVariablesError)

CALL "%TC_PathToScriptFolder%TST.bat" /Set null SqlTestPrefix NULL_P1_ >>%TC_PreserveTSTVariablesOutput%
IF ERRORLEVEL 1 (ECHO Error setting a TST variable.>&2& GOTO LblPreserveTSTVariablesError)

CALL "%TC_PathToScriptFolder%TST.bat" /Set null SqlTestPrefix NULL_P2_ >>%TC_PreserveTSTVariablesOutput%
IF ERRORLEVEL 1 (ECHO Error setting a TST variable.>&2& GOTO LblPreserveTSTVariablesError)

ECHO. >>%TC_PreserveTSTVariablesOutput%
ECHO Setting TST while preserving the TST variables. >>%TC_PreserveTSTVariablesOutput%
ECHO. >>%TC_PreserveTSTVariablesOutput%

CALL "%TC_PathToScriptFolder%TST.bat" /Force >>%TC_PreserveTSTVariablesOutput%
IF ERRORLEVEL 1 (
   ECHO Error testing preserving the TST Variables.>&2
   ECHO Error setting up the TST database [phase 2].>&2
   GOTO LblPreserveTSTVariablesError
)

CALL "%TC_PathToScriptFolder%TST.bat" /Get >>%TC_PreserveTSTVariablesOutput%
IF ERRORLEVEL 1 (ECHO Error displaying the TST variables.>&2& GOTO LblPreserveTSTVariablesError)

sqlcmd %TC_SqlCmdParameters% -d TST -Q "DELETE Data.TSTVariables" > %TC_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error cleaning table Data.TSTVariables.>&2
   TYPE %TC_SqlOutput% >&2
   GOTO LblPreserveTSTVariablesError
)

GOTO LblPreserveTSTVariablesDone

:LblPreserveTSTVariablesError
SET TC_PreserveTSTVariablesExitCode=1

:LblPreserveTSTVariablesDone

EXIT /B %TC_PreserveTSTVariablesExitCode%
GOTO :EOF

REM ==============================================================
REM Runs a command and compares the output with a baseline file
REM ==============================================================
:SubValidateAgainstBaseline

SET TC_TestCase=%1
SET TC_ActualOutput="%~2"
SET TC_BaselineOutput="%~3"

SET TC_ValidateBaselineExitCode=0

ECHO N | COMP %TC_ActualOutput% %TC_BaselineOutput% >nul 2>&1
IF ERRORLEVEL 1 (
   ECHO.
   ECHO Error comparing the ouput for %TC_TestCase% >&2
   ECHO      Output: %TC_CommandOutput% >&2
   ECHO    Baseline: %TC_BaselineOutput% >&2
   SET TC_ValidateBaselineExitCode=1
   GOTO LblValidateAgainstBaselineDone
)

ECHO Comparing the ouput for %TC_TestCase% OK

:LblValidateAgainstBaselineDone

EXIT /B %TC_ValidateBaselineExitCode%
GOTO :EOF


REM ==============================================================
REM Prints a help page to the output
REM ==============================================================
:SubHelpPage

ECHO.
ECHO TSTCheck.bat - Contains a self test for TST.
ECHO Usage: TSTCheck.bat [/?]
ECHO.       /?           Will display this help page.
ECHO.
ECHO TSTCheck.bat will run test automation that validates the TST framework.
ECHO.

GOTO :EOF
