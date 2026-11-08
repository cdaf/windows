@ECHO OFF
cmd /c "exit 0"

rem This script is a simple lauch script

set BUILDNUMBER=%1
set REVISION=%2
set ACTION=%3
set LOCAL_WORK_DIR=%4
set REMOTE_WORK_DIR=%5

set CDAF_COMMAND_SHELL=yes

for %%Q in ("%~dp0\.") do set "AUTOMATIONROOT=%%~fQ"

echo.
echo [     %~nx0     ] ============================================
echo [     %~nx0     ] Continuous Integration (CI) Process Starting
echo [     %~nx0     ] ============================================

rem Launcher script that overides execution policy
rem cannot elevate powershell

rem Convert double quotes to single quotes so arguments containing spaces survive the -command string
set "CDAF_ARGS=%*"
if defined CDAF_ARGS set CDAF_ARGS=%CDAF_ARGS:"='%

call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command "& '%AUTOMATIONROOT%\processor\buildPackage.ps1' %CDAF_ARGS%"
set result=%errorlevel%
if %result% NEQ 0 (
	echo [%~nx0] BUILD_PACKAGE_ERROR call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %AUTOMATIONROOT%\processor\buildPackage.ps1 %CDAF_ARGS%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	exit /b %result%
)
