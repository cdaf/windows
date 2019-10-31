@ECHO OFF
cmd /c "exit 0"

REM This script is for use with Git only and is dependent on "master" branch naming convention

REM Action can be used to pass staging directory with staging@ prefix or 
REM housekeeping with remoteURL@

SET BUILDNUMBER=%1
SET BRANCH=%2
SET ACTION=%3
set AUTOMATION_ROOT=%4

IF [%AUTOMATION_ROOT%] == [] (
	set automationRoot=automation
) else (
	set automationRoot=%AUTOMATION_ROOT%
)

echo.
echo [%~nx0] --------------------
echo [%~nx0] Targetless Branch CD
echo [%~nx0]   BUILDNUMBER     : %BUILDNUMBER%
echo [%~nx0]   BRANCH          : %BRANCH%
echo [%~nx0]   ACTION          : %ACTION%
echo [%~nx0]   AUTOMATION_ROOT : %automationRoot%

REM Launcher script that overides execution policy
REM cannot elevate powershell

IF "%BRANCH%" == "master" (
	GOTO StagingArtefacts
)

echo [%~nx0] Do not pass ACTION when executing feature branch (non-master)
call %cd%\%automationRoot%\processor\buildPackage.bat %BUILDNUMBER% %BRANCH%
SET result=%ERRORLEVEL%
if %result% NEQ 0 (
	echo [%~nx0] ERROR call %cd%\%automationRoot%\processor\buildPackage.bat %BUILDNUMBER% %BRANCH%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	echo.
    echo [%~nx0] --- End Targetless Branch CI Error Handling ---
	echo.
	exit /b %result%
)
GOTO BranchCheck

:StagingArtefacts
call %cd%\%automationRoot%\processor\buildPackage.bat %BUILDNUMBER% %BRANCH% %ACTION%
SET result=%ERRORLEVEL%
if %result% NEQ 0 (
	echo [%~nx0] ERROR call %cd%\%automationRoot%\processor\buildPackage.bat %BUILDNUMBER% %BRANCH% %ACTION%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	echo.
    echo [%~nx0] --- End Targetless Branch CI Error Handling ---
	echo.
	exit /b %result%
)

:BranchCheck
IF "%BRANCH%" == "master" (
	echo [%~nx0] Only perform container test in CI for branches, Master execution in CD pipeline
	GOTO GitClean
)

IF "%BRANCH%" == "refs/heads/master" (
	echo [%~nx0] Only perform container test in CI for branches, Master execution in CD pipeline
	GOTO GitClean
)

REM Do not call from within IF statement or errorlevel is lost
echo [%~nx0] Only perform container test in CI for feature branches, CD for branch %BRANCH%
call %CD%\TasksLocal\delivery.bat DOCKER
SET result=%ERRORLEVEL%
if %result% NEQ 0 (
	echo [%~nx0] ERROR call %CD%\TasksLocal\delivery.bat DOCKER
	echo [%~nx0]   Return LASTEXITCODE %result% 
	echo.
    echo [%~nx0] --- End Targetless Branch CD Error Handling ---
	echo.
	exit /b %result%
)

:GitClean
call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %cd%\%automationRoot%\processor\entry.ps1 %BRANCH% %ACTION%
set result=%errorlevel%
if %result% NEQ 0 (
	echo [%~nx0] BUILD_PACKAGE_ERROR call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %cd%\%automationRoot%\processor\entry.ps1 %BRANCH% %ACTION%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	exit /b %result%
)
exit /b 0