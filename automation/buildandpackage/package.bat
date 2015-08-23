@echo off

set SOLUTION=%1
set BUILDNUMBER=%2
set REVISION=%3
set LOCAL_WORK_DIR=%4
set REMOTE_WORK_DIR=%5
set ACTION=%6

set automationRoot=automation

echo.
echo [%~nx0] -------------------
echo [%~nx0]   Package Process
echo [%~nx0] -------------------
echo [%~nx0]   SOLUTION                : %SOLUTION%
echo [%~nx0]   BUILDNUMBER             : %BUILDNUMBER%
echo [%~nx0]   REVISION                : %REVISION%
echo [%~nx0]   LOCAL_WORK_DIR          : %LOCAL_WORK_DIR%
echo [%~nx0]   REMOTE_WORK_DIR         : %REMOTE_WORK_DIR%
echo [%~nx0]   ACTION                  : %ACTION%

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%automationRoot%\buildandpackage\package.ps1 %SOLUTION% %BUILDNUMBER% %REVISION% %LOCAL_WORK_DIR% %REMOTE_WORK_DIR% %automationRoot% %ACTION%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%automationRoot%\buildandpackage\package.ps1 %SOLUTION% %BUILDNUMBER% %REVISION% %LOCAL_WORK_DIR% %REMOTE_WORK_DIR% %automationRoot% %ACTION% failed!
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)
