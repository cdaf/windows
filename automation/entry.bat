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
	set "automationRoot=%~dp0"
) else (
	set "automationRoot=%AUTOMATION_ROOT%"
)

echo.
echo [%~nx0] --------------------
echo [%~nx0] Git workspace processing
echo [%~nx0]   AUTOMATION_ROOT : %automationRoot%
echo [%~nx0]   BUILDNUMBER     : %BUILDNUMBER%
echo [%~nx0]   BRANCH          : %BRANCH%
echo [%~nx0]   ACTION          : %ACTION%

REM Launcher script that overides execution policy
REM cannot elevate powershell

call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %automationRoot%\processor\entry.ps1 %automationRoot% %BUILDNUMBER% %BRANCH% %ACTION%
set result=%errorlevel%
if %result% NEQ 0 (
	echo [%~nx0] DELIVERY_ERROR call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %automationRoot%\processor\entry.ps1 %automationRoot% %BUILDNUMBER% %BRANCH% %ACTION%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	exit /b %result%
)
