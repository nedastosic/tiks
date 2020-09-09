@ECHO OFF
SET TSEH_Output=%1

SET TSEH_PathToScriptFolder=%~dp0

ECHO. >%TSEH_Output%
CALL "%TSEH_PathToScriptFolder%..\TST.BAT" /NoVerCheck >>%TSEH_Output% 2>>&1
ECHO ========================== >>%TSEH_Output% 2>>&1
CALL "%TSEH_PathToScriptFolder%..\TST.BAT" /NoPause >>%TSEH_Output% 2>>&1
ECHO ========================== >>%TSEH_Output% 2>>&1
CALL "%TSEH_PathToScriptFolder%..\TST.BAT" /RunAll >>%TSEH_Output% 2>>&1
ECHO ========================== >>%TSEH_Output% 2>>&1
CALL "%TSEH_PathToScriptFolder%..\TST.BAT" /RunSuite >>%TSEH_Output% 2>>&1
ECHO ========================== >>%TSEH_Output% 2>>&1
CALL "%TSEH_PathToScriptFolder%..\TST.BAT" /RunSuite DatabaseName >>%TSEH_Output% 2>>&1
ECHO ========================== >>%TSEH_Output% 2>>&1
CALL "%TSEH_PathToScriptFolder%..\TST.BAT" /RunTest >>%TSEH_Output% 2>>&1
ECHO ========================== >>%TSEH_Output% 2>>&1
CALL "%TSEH_PathToScriptFolder%..\TST.BAT" /RunTest DatabaseName >>%TSEH_Output% 2>>&1
ECHO ========================== >>%TSEH_Output% 2>>&1
CALL "%TSEH_PathToScriptFolder%..\TST.BAT" /RunAll Databasename /RunSuite DatabaseName SuiteName >>%TSEH_Output% 2>>&1
ECHO ========================== >>%TSEH_Output% 2>>&1
CALL "%TSEH_PathToScriptFolder%..\TST.BAT" /RunAll Databasename /RunTest  DatabaseName TestName >>%TSEH_Output% 2>>&1
ECHO ========================== >>%TSEH_Output% 2>>&1
CALL "%TSEH_PathToScriptFolder%..\TST.BAT" /RunSuite DatabaseName SuiteName /RunTest  DatabaseName TestName >>%TSEH_Output% 2>>&1
ECHO ========================== >>%TSEH_Output% 2>>&1
CALL "%TSEH_PathToScriptFolder%..\TST.BAT" /XmlResult XmlFilePath >>%TSEH_Output% 2>>&1
ECHO ========================== >>%TSEH_Output% 2>>&1
CALL "%TSEH_PathToScriptFolder%..\TST.BAT" /XmlResult XmlFilePath >>%TSEH_Output% 2>>&1
ECHO ========================== >>%TSEH_Output% 2>>&1
CALL "%TSEH_PathToScriptFolder%..\TST.BAT" /NoTimeStamp >>%TSEH_Output% 2>>&1
ECHO ========================== >>%TSEH_Output% 2>>&1
CALL "%TSEH_PathToScriptFolder%..\TST.BAT" /Verbose >>%TSEH_Output% 2>>&1
ECHO ========================== >>%TSEH_Output% 2>>&1




