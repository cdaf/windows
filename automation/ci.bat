@ECHO OFF
cmd /c "exit 0"

REM This script is a simple lauch script

SET BUILDNUMBER=%1
SET REVISION=%2
SET ACTION=%3
SET LOCAL_WORK_DIR=%4
SET REMOTE_WORK_DIR=%5

for %%Q in ("%~dp0\.") DO set "AUTOMATIONROOT=%%~fQ"

echo.
echo [     %~nx0     ] ============================================
echo [     %~nx0     ] Continuous Integration (CI) Process Starting
echo [     %~nx0     ] ============================================

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command "& '%AUTOMATIONROOT%\processor\buildPackage.ps1'" "%BUILDNUMBER%" "%REVISION%" "%ACTION%" "%LOCAL_WORK_DIR%" "%REMOTE_WORK_DIR%"
SET result=%errorlevel%
if %result% NEQ 0 (
	echo [%~nx0] BUILD_PACKAGE_ERROR call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command & %AUTOMATIONROOT%\processor\buildPackage.ps1 %BUILDNUMBER% %REVISION% %ACTION% %AUTOMATION_ROOT% %LOCAL_WORK_DIR% %REMOTE_WORK_DIR%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	exit /b %result%
)
