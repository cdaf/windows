@echo off
echo.
echo [%~nx0] ============================================
echo [%~nx0] Continuous Integration (CI) Process Starting
echo [%~nx0] ============================================

set BUILDNUMBER=%1
set REVISION=%2
set ACTION=%3
set SOLUTION=%4
set AUTOMATION_ROOT=%5
set LOCAL_WORK_DIR=%6
set REMOTE_WORK_DIR=%7

IF [%AUTOMATION_ROOT%] == [] (
	set automationRoot=automation
) else (
	set automationRoot=%AUTOMATION_ROOT%
)

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%automationRoot%\processor\buildPackage.ps1 %BUILDNUMBER% %REVISION% %ACTION% %SOLUTION% %AUTOMATION_ROOT% %LOCAL_WORK_DIR% %REMOTE_WORK_DIR%  
set result=%errorlevel%
if %result% NEQ 0 (
	echo [%~nx0] BUILD_PACKAGE_ERROR call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%automationRoot%\processor\buildPackage.ps1 %BUILDNUMBER% %REVISION% %ACTION% %SOLUTION% %AUTOMATION_ROOT% %LOCAL_WORK_DIR% %REMOTE_WORK_DIR%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	exit /b %result%
)
