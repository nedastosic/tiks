@ECHO OFF
IF "%useverbose%"=="1" ECHO ON
REM ===================================================
REM This is the TST main utility.
REM For help run TST.bat /?
REM For License and History see file SetTSTDatabase.sql
REM ===================================================
SETLOCAL

SET TST_MajorVersion=1
SET TST_MinorVersion=8

SET TST_VariablesFoundBeforeSetup=0
SET TST_ExitCode=1
SET TST_XmlResults=0
SET TST_XmlResultsPath=
SET TST_NoTimestamp=0
SET TST_Verbose=0
SET TST_Setup=0
SET TST_QuickStart=0
SET TST_RunAllTests=0
SET TST_RunSuite=0
SET TST_RunTest=0
SET TST_DatabaseToTest=
SET TST_SuiteName=
SET TST_TestName=
SET TST_PathToScriptFolder=%~dp0
SET TST_SqlOutput="%Temp%\TST_SqlOutput.txt"
SET TST_VariablesBeforeSetupOutput="%Temp%\TST_TSTVariables.txt"
SET TST_SqlTestOutput="%Temp%\TST_SqlTestOutput.txt"
SET TST_MiscOutput="%Temp%\TST_MiscOutput.txt"
SET TST_SqlGenerateXmlOutput="%Temp%\TST_SqlGenerateXmlOutput.txt"
SET TST_SqlServer=localhost
SET TST_PauseAtEnd=0
SET TST_NoPauseAtEnd=0
SET TST_SqlTestParameters=
SET TST_SqlPrintParameters=
SET TST_NoVerCheck=0
SET TST_UseExit=0
SET TST_Get=0
SET TST_Set=0
SET TST_SetVariableDatabaseName=
SET TST_SetVariableName=
SET TST_SetVariableValue=

REM If no parameters are specified then assume /Setup
IF /I "%1"=="" (SET TST_Setup=1& GOTO LblDoneCmdParameters)

:LblProcessParameter

IF /I "%1"=="" ( GOTO LblDoneCmdParameters)

IF /I "%1"=="/?"           (CALL :SubHelpPage&      SET TST_ExitCode=0&         GOTO LblDone)
IF /I "%1"=="/Help"        (CALL :SubHelpPage&      SET TST_ExitCode=0&         GOTO LblDone)
IF /I "%1"=="/Server"      (SET TST_SqlServer=%~2&  GOTO LblNextCmdParameter2)
IF /I "%1"=="/Setup"       (SET TST_Setup=1&        GOTO LblNextCmdParameter1)
IF /I "%1"=="/NoVerCheck"  (SET TST_NoVerCheck=1&   GOTO LblNextCmdParameter1)
IF /I "%1"=="/RunAll"      (SET TST_RunAllTests=1&  SET TST_DatabaseToTest=%~2& GOTO LblNextCmdParameter2)
IF /I "%1"=="/RunSuite"    (SET TST_RunSuite=1&     SET TST_DatabaseToTest=%~2& SET TST_SuiteName=%~3&   GOTO LblNextCmdParameter3)
IF /I "%1"=="/RunTest"     (SET TST_RunTest=1&      SET TST_DatabaseToTest=%~2& SET TST_TestName=%~3&    GOTO LblNextCmdParameter3)
IF /I "%1"=="/NoPause"     (SET TST_NoPauseAtEnd=1& GOTO LblNextCmdParameter1)
IF /I "%1"=="/XmlFormat"   (SET TST_XmlResults=1&   SET TST_XmlResultsPath=%~2&  GOTO LblNextCmdParameter2)
IF /I "%1"=="/Get"         (SET TST_Get=1&          GOTO LblNextCmdParameter1)
IF /I "%1"=="/Set"         (SET /A TST_Set=%TST_Set%+1&& SET TST_SetVariableDatabaseName=%~2& SET TST_SetVariableName=%~3& SET TST_SetVariableValue=%~4& GOTO LblNextCmdParameter4)
IF /I "%1"=="/UseEXIT"     (SET TST_UseExit=1&      GOTO LblNextCmdParameter1)
IF /I "%1"=="/NoTimestamp" (SET TST_NoTimestamp=1&  GOTO LblNextCmdParameter1)
IF /I "%1"=="/Verbose"     (SET TST_Verbose=1&      GOTO LblNextCmdParameter1)
IF /I "%1"=="/QuickStart"  (SET TST_QuickStart=1&   GOTO LblNextCmdParameter1)
IF /I "%1"=="/Force"       (SET TST_Setup=1&        SET TST_NoVerCheck=1&        SET TST_NoPauseAtEnd=1& GOTO LblNextCmdParameter1)

ECHO Invalid command line parameters. Unknown parameter: '%1'>&2
ECHO Run TST.bat /?>&2
SET TST_ExitCode=1
GOTO LblDone

:LblNextCmdParameter4
SHIFT /1

:LblNextCmdParameter3
SHIFT /1

:LblNextCmdParameter2
SHIFT /1

:LblNextCmdParameter1
SHIFT /1
GOTO LblProcessParameter

:LblDoneCmdParameters

IF %TST_Set% GTR 1 (
      ECHO Invalid command line parameters. '/Set' can only be specified once.>&2
      SET TST_ExitCode=1
      GOTO LblDone
)

SET TST_SqlCmdParameters=-b -S %TST_SqlServer% -E

CALL :SubVefifyCommandParameters
IF ERRORLEVEL 1 (
      SET TST_ExitCode=1
      GOTO LblDone
)

CALL :SubSQLCMDAccessible
IF ERRORLEVEL 1 (
      SET TST_ExitCode=1
      GOTO LblDone
)

IF "%TST_Setup%%TST_NoPauseAtEnd%"=="10" (SET TST_PauseAtEnd=1)
IF "%TST_XmlResults%"=="1" (
   SET TST_SqlTestParameters=, @ResultsFormat='Batch', @CleanTemporaryData=0
)

IF "%TST_NoTimestamp%"=="1" (SET TST_SqlTestParameters=%TST_SqlTestParameters%, @NoTimestamp=1)
IF "%TST_Verbose%"=="1"     (SET TST_SqlTestParameters=%TST_SqlTestParameters%, @Verbose=1)

IF "%TST_NoTimestamp%"=="1" (SET TST_SqlPrintParameters=%TST_SqlPrintParameters%, @NoTimestamp=1)
IF "%TST_Verbose%"=="1"     (SET TST_SqlPrintParameters=%TST_SqlPrintParameters%, @Verbose=1)


SET TST_ExitCode=0
IF       "%TST_Setup%"=="1"    (CALL :SubExecuteSetup          & IF ERRORLEVEL 1 (GOTO LblFatalError) ELSE (GOTO :LblDone) )
IF         "%TST_Set%"=="1"    (CALL :SubExecuteSetVariable    %TST_SetVariableDatabaseName% %TST_SetVariableName% %TST_SetVariableValue%& IF ERRORLEVEL 1 (GOTO LblFatalError) ELSE (GOTO :LblDone) )
IF         "%TST_Get%"=="1"    (CALL :SubExecuteGetVariables   & IF ERRORLEVEL 1 (GOTO LblFatalError) ELSE (GOTO :LblDone) )
IF  "%TST_QuickStart%"=="1"    (CALL :SubSetupQuickStart       & IF ERRORLEVEL 1 (GOTO LblFatalError) ELSE (GOTO :LblDone) )
IF "%TST_RunAllTests%"=="1"    (CALL :SubRunAllTests           & IF ERRORLEVEL 1 (GOTO LblFatalError) ELSE (GOTO :LblDone) )
IF    "%TST_RunSuite%"=="1"    (CALL :SubRunSuite              & IF ERRORLEVEL 1 (GOTO LblFatalError) ELSE (GOTO :LblDone) )
IF     "%TST_RunTest%"=="1"    (CALL :SubRunTest               & IF ERRORLEVEL 1 (GOTO LblFatalError) ELSE (GOTO :LblDone) )

:LblDone

IF /I "%TST_TSTTestStatus%"=="Failed" (SET TST_ExitCode=1)
IF "%TST_PauseAtEnd%"=="1" (PAUSE Hit any key to exit)
IF "%TST_UseExit%"=="1" (EXIT %TST_ExitCode%) ELSE (EXIT /B %TST_ExitCode%)

ENDLOCAL
GOTO :EOF

:LblFatalError
SET TST_ExitCode=1
GOTO LblDone

REM ==============================================================
REM Validates the command line parameters
REM Return code: 
REM   0 - OK
REM   1 - Invalid command line parameters. An error message was 
REM       already displayed.
REM ==============================================================
:SubVefifyCommandParameters

SET TST_CmdParamExitCode=0

IF "%TST_SqlServer%" == "" (
   ECHO Invalid command line parameters.>&2
   ECHO Invalid SQL Server name.>&2
   GOTO LblCmdParamError
)

IF NOT "%TST_RunAllTests%" == "1" GOTO LblAfter_Validate_RunAllTests
IF "%TST_DatabaseToTest%" == "" (
   ECHO Invalid command line parameters.>&2
   ECHO You must specify the database to be tested.>&2
   GOTO LblCmdParamError
)

:LblAfter_Validate_RunAllTests

IF NOT "%TST_RunSuite%" == "1" GOTO LblAfter_Validate_RunSuite
IF "%TST_DatabaseToTest%" == "" (
   ECHO Invalid command line parameters.>&2
   ECHO You must specify the database to be tested.>&2
   GOTO LblCmdParamError
)
IF "%TST_SuiteName%" == "" (
   ECHO Invalid command line parameters.>&2
   ECHO You must specify the suite name.>&2
   GOTO LblCmdParamError
)

IF "%TST_RunAllTests%" == "1" (
      ECHO Invalid command line parameters.>&2
      ECHO You cannot specify both /RunAll and /RunSuite.>&2
      GOTO LblCmdParamError
)

:LblAfter_Validate_RunSuite

IF NOT "%TST_RunTest%" == "1" GOTO LblAfter_Validate_RunTest
   IF "%TST_DatabaseToTest%" == "" (
      ECHO Invalid command line parameters.>&2
      ECHO You must specify the database to be tested.>&2
      GOTO LblCmdParamError
   )
   IF "%TST_TestName%" == "" (
      ECHO Invalid command line parameters.>&2
      ECHO You must specify the test name.>&2
      GOTO LblCmdParamError
   )
)

IF "%TST_RunAllTests%" == "1" (
   ECHO Invalid command line parameters.>&2
   ECHO You cannot specify both /RunAll and /RunTest.>&2
   GOTO LblCmdParamError
)

IF "%TST_RunSuite%" == "1" (
   ECHO Invalid command line parameters.>&2
   ECHO You cannot specify both /RunSuite and /RunTest.>&2
   GOTO LblCmdParamError
)


:LblAfter_Validate_RunTest


IF "%TST_NoVerCheck%%TST_Setup%" == "10" (
   ECHO Invalid command line parameters.>&2
   ECHO You cannot specify /NoVerCheck unless you specify /Setup.>&2
   GOTO LblCmdParamError
)

IF "%TST_NoPauseAtEnd%%TST_Setup%" == "10" (
   ECHO Invalid command line parameters.>&2
   ECHO You cannot specify /NoPause unless you specify /Setup.>&2
   GOTO LblCmdParamError
)

IF "%TST_XmlResults%%TST_RunAllTests%%TST_RunSuite%%TST_RunTest%" == "1000" (
   ECHO Invalid command line parameters.>&2
   ECHO You cannot specify /XmlResult unless you specify one of the /Run options.>&2
   GOTO LblCmdParamError
)

IF "%TST_XmlResults%%" == "1" (
   IF NOT DEFINED TST_XmlResultsPath (
      ECHO Invalid command line parameters.>&2
      ECHO Following /XmlFormat you must specify the path to the XML file.>&2
      GOTO LblCmdParamError
   )
)

IF "%TST_NoTimestamp%%TST_RunAllTests%%TST_RunSuite%%TST_RunTest%" == "1000" (
   ECHO Invalid command line parameters.>&2
   ECHO You cannot specify /NoTimestamp unless you specify one of the /Run options.>&2
   GOTO LblCmdParamError
)

IF "%TST_Verbose%%TST_RunAllTests%%TST_RunSuite%%TST_RunTest%" == "1000" (
   ECHO Invalid command line parameters.>&2
   ECHO You cannot specify /Verbose unless you specify one of the /Run options.>&2
   GOTO LblCmdParamError
)

GOTO Lbl_Validate_ParamDone

:LblCmdParamError
ECHO Run TST.bat /?>&2
SET TST_CmdParamExitCode=1


:Lbl_Validate_ParamDone
EXIT /B %TST_CmdParamExitCode%
GOTO :EOF


REM ==============================================================
REM Sets up the TSTQuickStart database.
REM Return code: 
REM   0 - OK
REM   1 - An error occured. An error message was already displayed.
REM ==============================================================
:SubSetupQuickStart

SET TST_QuickStartSetupExitCode=0

sqlcmd %TST_SqlCmdParameters% -i "%TST_PathToScriptFolder%Doc\SetTSTQuickStart.sql" > %TST_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error setting up the TSTQuickStart database.>&2
   ECHO See %TST_SqlOutput% >&2
   SET TST_QuickStartSetupExitCode=1
   GOTO LblSetupQuickStartDone
)

ECHO The database TSTQuickStart was successfully set-up.
GOTO LblSetupDone

:LblSetupQuickStartDone
EXIT /B %TST_QuickStartSetupExitCode%
GOTO :EOF


REM ==============================================================
REM Sets a TST variable as indicated by the command parameters.
REM Return code: 
REM   0 - OK
REM   1 - An error occured. An error message was already displayed.
REM ==============================================================
:SubExecuteSetVariable

SET TST_SetVarDatabaseName=%~1
SET TST_SetVarName=%~2
SET TST_SetVarValue=%~3

SET TST_SetVariableExitCode=0

SET TST_SetVarDatabaseNameParam='%TST_SetVarDatabaseName%'
IF /I "%TST_SetVarDatabaseName%"=="NULL" SET TST_SetVarDatabaseNameParam=NULL

sqlcmd %TST_SqlCmdParameters% -d TST -Q "EXEC Utils.SetTSTVariable %TST_SetVarDatabaseNameParam%, '%TST_SetVarName%', '%TST_SetVarValue%'" > %TST_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error setting the TST Variable.>&2
   ECHO See %TST_SqlOutput% >&2
   GOTO LblExecuteSetVariableError
)

GOTO LblExecuteSetVariableDone

:LblExecuteSetVariableError
SET TST_SetVariableExitCode=1

:LblExecuteSetVariableDone
EXIT /B %TST_SetVariableExitCode%
GOTO :EOF

REM ==============================================================
REM Displays all TST variables.
REM Return code: 
REM   0 - OK
REM   1 - An error occured. An error message was already displayed.
REM ==============================================================
:SubExecuteGetVariables

SET TST_GetVariablesExitCode=0
SET TST_VariablesFound=0

sqlcmd %TST_SqlCmdParameters% -d TST -Q "SELECT 'TST_Var', DatabaseName, VariableName, VariableValue FROM Data.TSTVariables" > %TST_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error querying the TST Variables.>&2
   ECHO See %TST_SqlOutput% >&2
   GOTO LblExecuteGetVariablesError
)

FOR /F "usebackq tokens=1,2,3,4" %%a in (%TST_SqlOutput%) do (
   IF "%%a"=="TST_Var" (
      ECHO Database=%%b, VariableName=%%c, VariableValue=%%d
      SET TST_VariablesFound=1
   )
)

IF "%TST_VariablesFound%" == "0" (
   ECHO No TST Variables were found. 
   ECHO Run TST /Set DatabaseName VariableName VariableValue
)

GOTO LblExecuteGetVariablesDone

:LblExecuteGetVariablesError
SET TST_GetVariablesExitCode=1

:LblExecuteGetVariablesDone
EXIT /B %TST_GetVariablesExitCode%
GOTO :EOF


REM ==============================================================
REM Collects info about existing TST variables if any
REM Return code: 
REM   0 - OK
REM   1 - An error occured. An error message was already displayed.
REM ==============================================================
:SubCollectTSTVariables

SET TST_VariablesFoundBeforeSetup=0
SET TST_CollectTSTVariablesExitCode=0

REM If No TST database is found then simply exit the procedure.
sqlcmd %TST_SqlCmdParameters% -Q "EXIT (SELECT COUNT([name]) FROM sys.databases WHERE [name] = 'TST')" > %TST_SqlOutput% 2>&1
IF "%ERRORLEVEL%"=="0" GOTO LblCollectTSTVariablesDone

REM If the TST database exists but does not have the TSTVariables table then simply exit the procedure.
sqlcmd %TST_SqlCmdParameters% -d TST -Q "EXIT (SELECT COUNT([TABLE_NAME]) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Data' AND TABLE_NAME = 'TSTVariables')" > %TST_SqlOutput% 2>&1
IF "%ERRORLEVEL%"=="0" GOTO LblCollectTSTVariablesDone

sqlcmd %TST_SqlCmdParameters% -d TST -Q "SELECT 'TST_Var', ISNULL(DatabaseName, 'NULL'), VariableName, VariableValue FROM Data.TSTVariables" > %TST_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error querying the TST Variables.>&2
   ECHO See %TST_SqlOutput% >&2
   GOTO LblCollectTSTVariablesError
)

DEL /F /Q %TST_VariablesBeforeSetupOutput% >nul 2>&1
IF EXIST %TST_VariablesBeforeSetupOutput% (
   ECHO Error: Unable to delete %TST_VariablesBeforeSetupOutput% >&2
   GOTO LblCollectTSTVariablesError
)

FOR /F "usebackq tokens=1,2,3,4" %%a in (%TST_SqlOutput%) do (
   IF "%%a"=="TST_Var" (
      ECHO %%b %%c %%d>>%TST_VariablesBeforeSetupOutput%
      SET TST_VariablesFoundBeforeSetup=1
   )
)

GOTO LblCollectTSTVariablesDone

:LblCollectTSTVariablesError
SET TST_CollectTSTVariablesExitCode=1

:LblCollectTSTVariablesDone
EXIT /B %TST_CollectTSTVariablesExitCode%
GOTO :EOF

CALL :SubRestoreTSTVariables
REM ==============================================================
REM Restores the TST variables if any were found during SubCollectTSTVariables
REM Return code: 
REM   0 - OK
REM   1 - An error occured. An error message was already displayed.
REM ==============================================================
:SubRestoreTSTVariables

SET TST_RestoreTSTVariablesExitCode=0

IF "%TST_VariablesFoundBeforeSetup%"=="0" GOTO LblRestoreTSTVariablesDone

FOR /F "usebackq tokens=1,2,3" %%a in (%TST_VariablesBeforeSetupOutput%) do (
   ECHO Restore TST Variable: DB=%%a Name=%%b Value=%%c
   CALL :SubExecuteSetVariable %%a %%b %%c
   IF ERRORLEVEL 1 GOTO LblRestoreTSTVariablesError
)

GOTO LblRestoreTSTVariablesDone

:LblRestoreTSTVariablesError
SET TST_RestoreTSTVariablesExitCode=1

:LblRestoreTSTVariablesDone
EXIT /B %TST_RestoreTSTVariablesExitCode%
GOTO :EOF

REM ==============================================================
REM Executes the TST setup as indicated by the command parameters.
REM Return code: 
REM   0 - OK
REM   1 - An error occured. An error message was already displayed.
REM ==============================================================
:SubExecuteSetup

SET TST_SetupExitCode=0

SET TST_ActualMajorVersion=Unknown
SET TST_ActualMinorVersion=Unknown
SET TST_TSTDatabaseSignature=Unknown

REM this will make sure SQL Server is started. 
sqlcmd %TST_SqlCmdParameters% -Q "SELECT 'SqlVersion.' + CAST(SERVERPROPERTY('ProductVersion') AS varchar)" > %TST_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error querying the SQL Server version.>&2
   ECHO Please make sure that SQL Server is started on the localhost.>&2
   ECHO See %TST_SqlOutput% >&2
   SET TST_SetupExitCode=1
   GOTO LblSetupDone   
)

SET TST_SQLFullVersion=Unknown
SET TST_SQLMajorVersion=0
FOR /F "usebackq tokens=1,2,3,4,5 delims=." %%a in (%TST_SqlOutput%) do (
   IF /I "%%a" == "SqlVersion" (SET TST_SQLMajorVersion=%%b&SET TST_SQLFullVersion=%%b.%%c.%%d.%%e)
)

IF %TST_SQLMajorVersion% LSS 9 (
   ECHO TST can run only on SQL Server 2005 ^(version 9^) or higher.>&2
   ECHO Your version is %TST_SQLFullVersion%>&2
   SET TST_SetupExitCode=1
   GOTO LblSetupDone   
)

REM If the TST database does not exist we can proceed to setting it up
sqlcmd %TST_SqlCmdParameters% -Q "EXIT (SELECT COUNT([name]) FROM sys.databases WHERE [name] = 'TST')" > %TST_SqlOutput% 2>&1
IF "%ERRORLEVEL%"=="0" GOTO LblExecuteSetup

REM If the TST database exists but does not apear to be a standard TST database we have to stop.
sqlcmd %TST_SqlCmdParameters% -d TST -Q "EXIT (SELECT COUNT([TABLE_NAME]) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Data' AND TABLE_NAME = 'TSTVersion')" > %TST_SqlOutput% 2>&1
IF "%ERRORLEVEL%"=="0" GOTO LblTSTNotRecognized

sqlcmd %TST_SqlCmdParameters% -d TST -Q "DECLARE @TSTSignature varchar(100); SELECT @TSTSignature=TSTSignature FROM Data.TSTVersion; PRINT 'TSTSignature ' + @TSTSignature" > %TST_SqlOutput% 2>&1
IF ERRORLEVEL 1 GOTO LblSetupErrorInSqlCmd
FOR /F "usebackq tokens=1,2" %%a in (%TST_SqlOutput%) do (
   IF /I "%%a" == "TSTSignature" (SET TST_TSTDatabaseSignature=%%b)
)
IF NOT "%TST_TSTDatabaseSignature%"=="TST-{6C57D85A-CE44-49ba-9286-A5227961DF02}" GOTO LblTSTNotRecognized

IF "%TST_NoVerCheck%" == "1" GOTO LblExecuteSetup

sqlcmd %TST_SqlCmdParameters% -d TST -Q "EXIT (SELECT MajorVersion FROM Data.TSTVersion)" > %TST_SqlOutput% 2>&1
SET TST_ActualMajorVersion=%ERRORLEVEL%

sqlcmd %TST_SqlCmdParameters% -d TST -Q "EXIT (SELECT MinorVersion FROM Data.TSTVersion)" > %TST_SqlOutput% 2>&1
SET TST_ActualMinorVersion=%ERRORLEVEL%

IF "%TST_ActualMajorVersion%"=="Unknown" GOTO LblTSTNotRecognized
IF "%TST_ActualMajorVersion%"=="Unknown" GOTO LblTSTNotRecognized

IF %TST_MajorVersion% GTR %TST_ActualMajorVersion% GOTO LblOverwriteOldVersionDB
IF %TST_MajorVersion% EQU %TST_ActualMajorVersion% (IF %TST_MinorVersion% GTR %TST_ActualMinorVersion% GOTO LblOverwriteOldVersionDB)

ECHO The TST database version %TST_ActualMajorVersion%.%TST_ActualMinorVersion% is already in place.
ECHO *** Install Aborted! Run "TST /Setup /NoVerCheck" to force an overwrite.
GOTO LblSetupDone

:LblTSTNotRecognized
ECHO There is already a TST database installed on this server but is is
ECHO not recognized as any version of THIS TST database. To avoid overwriting
ECHO an unrelated database the TST setup was aborted. You will have to delete 
ECHO the TST database manually and rerun this setup.
SET TST_SetupExitCode=1
GOTO LblSetupDone

:LblOverwriteOldVersionDB
ECHO Overwriting the TST database version %TST_ActualMajorVersion%.%TST_ActualMinorVersion%.

:LblExecuteSetup

CALL :SubCollectTSTVariables
IF ERRORLEVEL 1 (SET TST_SetupExitCode=1& GOTO LblSetupDone)

sqlcmd %TST_SqlCmdParameters% -v MajorVersion=%TST_MajorVersion% -v MinorVersion=%TST_MinorVersion% -i "%TST_PathToScriptFolder%SetTSTDatabase.sql" > %TST_SqlOutput% 2>&1
IF ERRORLEVEL 1 GOTO LblSetupErrorInSqlCmd

CALL :SubRestoreTSTVariables 
IF ERRORLEVEL 1 (SET TST_SetupExitCode=1& GOTO LblSetupDone)

ECHO The TST database version %TST_MajorVersion%.%TST_MinorVersion% was successfully set-up.
GOTO LblSetupDone

:LblSetupErrorInSqlCmd
ECHO Error setting up the TST database.>&2
ECHO See %TST_SqlOutput% >&2
SET TST_SetupExitCode=1
GOTO LblSetupDone

:LblSetupDone
EXIT /B %TST_SetupExitCode%
GOTO :EOF


REM ==============================================================
REM Executes all tests as indicated by the command parameters.
REM Return code: 
REM   0 - OK
REM   1 - A failure or an error occured. An error message was 
REM       already displayed.
REM ==============================================================
:SubRunAllTests

SET TST_RunAllTestsExitCode=0

sqlcmd %TST_SqlCmdParameters% -d TST -Q "EXEC TST.Runner.RunAll @TestDatabaseName='%TST_DatabaseToTest%' %TST_SqlTestParameters%" > %TST_SqlTestOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error running the TST tests.>&2
   ECHO See %TST_SqlTestOutput% >&2
   SET TST_RunAllTestsExitCode=1
   GOTO LblRunAllTestsDone
)

CALL :SubGenerateResults %TST_SqlTestOutput%
IF ERRORLEVEL 1 (
   SET TST_RunAllTestsExitCode=1
   GOTO LblRunAllTestsDone
)

:LblRunAllTestsDone
EXIT /B %TST_RunAllTestsExitCode%
GOTO :EOF

REM ==============================================================
REM Executes all tests in a given suite as indicated by the 
REM command parameters.
REM Return code: 
REM   0 - OK
REM   1 - A failure or an error occured. An error message was 
REM       already displayed.
REM ==============================================================
:SubRunSuite

SET TST_RunSuiteExitCode=0

sqlcmd %TST_SqlCmdParameters% -d TST -Q "EXEC TST.Runner.RunSuite @TestDatabaseName='%TST_DatabaseToTest%', @SuiteName='%TST_SuiteName%' %TST_SqlTestParameters%" > %TST_SqlTestOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error running the TST suite '%TST_SuiteName%'.>&2
   ECHO See %TST_SqlTestOutput% >&2
   SET TST_RunSuiteExitCode=1
   GOTO LblRunSuiteDone
)

CALL :SubGenerateResults %TST_SqlTestOutput%
IF ERRORLEVEL 1 (
   SET TST_RunSuiteExitCode=1
   GOTO LblRunSuiteDone
)

:LblRunSuiteDone
EXIT /B %TST_RunSuiteExitCode%
GOTO :EOF


REM ==============================================================
REM Executes a given test as indicated by the command parameters.
REM Return code: 
REM   0 - OK
REM   1 - A failure or an error occured. An error message was 
REM       already displayed.
REM ==============================================================
:SubRunTest

SET TST_RunTestExitCode=0

sqlcmd %TST_SqlCmdParameters% -d TST -Q "EXEC TST.Runner.RunTest @TestDatabaseName='%TST_DatabaseToTest%', @TestName='%TST_TestName%' %TST_SqlTestParameters%" > %TST_SqlTestOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error running the TST test '%TST_TestName%'.>&2
   ECHO See %TST_SqlTestOutput% >&2
   SET TST_RunTestExitCode=1
   GOTO LblRunTest
)

CALL :SubGenerateResults %TST_SqlTestOutput%
IF ERRORLEVEL 1 (
   SET TST_RunTestExitCode=1
   GOTO LblRunTest
)

:LblRunTest
EXIT /B %TST_RunTestExitCode%
GOTO :EOF


REM ==============================================================
REM Prints the TST results, determines the test outcome
REM and if needed generates the results in XML format. 
REM Arguments: 
REM   %1 - The path to the TST output file.
REM Exit code:
REM   0 - OK
REM   1 - Error. An error message was already displayed.
REM ==============================================================
:SubGenerateResults

SET TST_TSTOutput="%~1"

TYPE %TST_TSTOutput%
CALL :SubProcessTSTOutput %TST_TSTOutput%
SET ERRORLEVEL=1
IF ERRORLEVEL 1 (GOTO :EOF)

IF "%TST_XmlResults%" == "1" (
   CALL :SubGenerateXmlResults
   IF ERRORLEVEL 1 (GOTO :EOF)
)

EXIT /B 0
GOTO :EOF


REM ==============================================================
REM Processes the TST output file and:
REM   - Determins the test session Id and saves it 
REM     in TST_TSTTestSessionId.
REM   - Determines the status of the TST tests and saves it 
REM     in TST_TSTTestStatus.
REM Arguments: 
REM   %1 - The path to the TST output file.
REM Exit code:
REM   0 - OK
REM   1 - Error. An error message was already displayed.
REM ==============================================================
:SubProcessTSTOutput

SET TST_TSTOutput="%~1"
SET TST_OutputExitCode=0

SET TST_TSTTestSessionId=Unknown
SET TST_TSTTestStatus=Unknown
FOR /F "usebackq tokens=1,2,3,4 delims=: " %%a in (%TST_TSTOutput%) do (
   IF /I "%%a%%b" == "TSTStatus" (SET TST_TSTTestStatus=%%c)
   IF /I "%%a%%b" == "TSTTestSessionId" (SET TST_TSTTestSessionId=%%c)
)

:LblAfterStatusWasSet

IF /I "%TST_TSTTestStatus%"=="Passed" (GOTO LblProcessOutputDone)

IF /I "%TST_TSTTestStatus%"=="Failed" (GOTO LblProcessOutputDone)
 
ECHO Error. Unable to parse the TST results.  Cannot identify 'TST Status'. See %TST_TSTOutput%
SET TST_OutputExitCode=1

:LblProcessOutputDone

EXIT /B %TST_OutputExitCode%
GOTO :EOF


REM ==============================================================
REM Generates the XML results. Assumes that TST_TSTTestSessionId
REM was set.
REM Return code: 
REM   0 - OK
REM   1 - A failure or an error occured. An error message was 
REM       already displayed.
REM ==============================================================
:SubGenerateXmlResults

SET TST_XmlExitCode=0

IF "%TST_TSTTestSessionId%"=="Unknown" (
   ECHO Error. Unable to parse the TST results. Cannot identify 'TST TestSessionId'.>&2
   ECHO See %TST_TSTOutput%>&2
   SET TST_XmlExitCode=1
   GOTO LblGenerateXmlDone
)

sqlcmd %TST_SqlCmdParameters% -d TST -Q "EXEC TST.Utils.PrintResults @TestSessionId=%TST_TSTTestSessionId%, @ResultsFormat='XML' %TST_SqlPrintParameters%" > %TST_SqlGenerateXmlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error generating the TST XML result file.>&2
   ECHO See %TST_SqlGenerateXmlOutput% >&2
   SET TST_XmlExitCode=1
   GOTO LblCleanSessiondata
)

COPY %TST_SqlGenerateXmlOutput% %TST_XmlResultsPath% >%TST_MiscOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error copying the XML resultfile.>&2
   TYPE %TST_MiscOutput% >&2
   SET TST_XmlExitCode=1
   GOTO LblCleanSessiondata
)

ECHO File %TST_XmlResultsPath% was saved.

:LblCleanSessiondata

REM We preserved temporary TST tables so that we can generate the XML results. Now these tables must be cleaned.
sqlcmd %TST_SqlCmdParameters% -d TST -Q "EXEC TST.Internal.CleanSessionData %TST_TSTTestSessionId%" > %TST_SqlOutput% 2>&1
IF ERRORLEVEL 1 (
   ECHO Error cleaning the temporary TST tables.>&2
   ECHO See %TST_SqlOutput% >&2
   SET TST_XmlExitCode=1
   GOTO LblGenerateXmlDone
)

:LblGenerateXmlDone
EXIT /B %TST_XmlExitCode%
GOTO :EOF


REM ==============================================================
REM Check if SQLCMD is accessible
REM ==============================================================
:SubSQLCMDAccessible

SQLCMD.EXE /? >nul 2>&1
IF NOT ERRORLEVEL 1 (
   EXIT /B 0
   GOTO :EOF
)

ECHO.
ECHO ERROR. SQLCMD.EXE is not accessible. Please make sure that: 
ECHO    - SQL Server is installled. 
ECHO    - The location of SQLCMD.EXE is in the PATH system environment 
ECHO      variable (this happens by default when SQL Server is installled).
ECHO.

EXIT /B 1
GOTO :EOF

REM ==============================================================
REM Prints a help page to the output
REM ==============================================================
:SubHelpPage

ECHO.
ECHO TST.bat - The Setup/Runner for TST %TST_MajorVersion%.%TST_MinorVersion%
ECHO Usage: TST.bat [/? ^| /Help] 
ECHO                    [/Server SqlServerName] 
ECHO                    [/QuickStart]
ECHO                    [/Setup /NoVerCheck /NoPause] ^|
ECHO                    [ (
ECHO                          [/RunAll   DatabaseToTest] ^|
ECHO                          [/RunSuite DatabaseToTest SuiteName] ^|
ECHO                          [/RunTest  DatabaseToTest TestName]
ECHO                      )
ECHO                      [/Verbose] [/XmlFormat PathToXmlFile] [/NoTimestamp]
ECHO                    ]
ECHO                    [/Set DatabaseName VariableName VariableValue] ^|
ECHO                    [/Get] ^|
ECHO                    [/UseEXIT]
ECHO.
ECHO. /?             Will display this help page.
ECHO. /Help          Will display this help page.
ECHO  /Server        Specifies the SQL Server that will be used. 
ECHO                 Default is localhost.
ECHO  /QuickStart    It will setup the TST Quick Start database.
ECHO  /Setup         If specified, the script will create the TST 
ECHO                 database version %TST_MajorVersion%.%TST_MinorVersion%
ECHO                 If the database 'TST' already exists and has 
ECHO                 a version older than %TST_MajorVersion%.%TST_MinorVersion% then 
ECHO                 it will be droped and recreated. 
ECHO                 If the database 'TST' version 1.8 already exists 
ECHO                 then the setup is aborted.
ECHO                 If TST.BAT is run with no parameter, then /Setup is assumed.
ECHO  /NoVerCheck    Valid only with /Setup. If specified the script will
ECHO                 create the TST database even if it already exists
ECHO                 regardless of its existing version. 
ECHO  /NoPause       Takes efect only when used with /Setup.
ECHO                 When specified the script will not display at the
ECHO                 end "Hit any key to exit".
ECHO  /Force         Equivalent with /Setup /NoVerCheck /NoPause.
ECHO  /RunAll        It will run all the TST test procedures 
ECHO                 from the database given by 'DatabaseToTest'
ECHO  /RunSuite      It will run all the TST test procedures 
ECHO                 from the database given by 'DatabaseToTest' and which
ECHO                 belong to the suite given by SuiteName
ECHO  /RunTest       It will run the TST test procedure with 
ECHO                 the name given by TestName from the database 
ECHO                 given by 'DatabaseToTest' 
ECHO  /Verbose       If /Verbose is not specified then only summary data, 
ECHO                 failures and errors are included in the test report. 
ECHO                 If /Verbose is specified all entries including the 
ECHO                 informational log entries and the ‘Pass’ log entries are
ECHO                 included in the test report.
ECHO  /XmlFormat     When specified it will dump the TST results
ECHO                 in the file given by PathToXmlFile
ECHO  /NoTimestamp   When specified no timestamps and duration info will 
ECHO                 be generated. Used to suport internal verification 
ECHO                 scripts.
ECHO  /Set           Will set a TST variable. 
ECHO                 TST variables are saved in the table Data.TSTVariables.
ECHO                 TST Variables are defined per test database.
ECHO                 Use NULL for the DatabaseName to set a global TST variable.
ECHO  /Get           Will display the values for all TST variables. 
ECHO  /UseEXIT       When specified it will set the ERRORLEVEL and exit 
ECHO                 the script with the EXIT command.
ECHO                 By default it will set the ERRORLEVEL by using 
ECHO                 Exit /B which does not cause the current DOS shell 
ECHO                 to be closed.
ECHO                 Using /UseEXIT is needed when integrating with some tools
ECHO                 in order to successfuly propagate the exit code. 
ECHO.
ECHO Exit Code:
ECHO     0 - Task(s) completed successfully.
ECHO     1 - There were errors completing the task(s).
ECHO         When the script is used to execute tests an exit code of 
ECHO         1 indicates that there were errors or failures.

GOTO :EOF
