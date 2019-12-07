@echo off
cmd /c "exit 0"
echo.
echo [%~nx0] ============================================
echo [%~nx0] Continuous Integration (CI) Process Starting
echo [%~nx0] ============================================

SET BUILDNUMBER=%1
SET REVISION=%2
SET ACTION=%3
SET SOLUTION=%4
SET AUTOMATION_ROOT=%5
SET LOCAL_WORK_DIR=%6
SET REMOTE_WORK_DIR=%7

IF [%AUTOMATION_ROOT%] == [] (
	REM Set automation root to parent, as this script is in processor subdirectory
	for %%I in ("%~dp0\..") do set "automationRoot=%%~fI"
) ELSE (
	SET "automationRoot=%AUTOMATION_ROOT%"
)

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %automationRoot%\processor\buildPackage.ps1 %BUILDNUMBER% %REVISION% %ACTION% %SOLUTION% %AUTOMATION_ROOT% %LOCAL_WORK_DIR% %REMOTE_WORK_DIR%  
SET result=%errorlevel%
if %result% NEQ 0 (
	echo [%~nx0] BUILD_PACKAGE_ERROR call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %automationRoot%\processor\buildPackage.ps1 %BUILDNUMBER% %REVISION% %ACTION% %SOLUTION% %AUTOMATION_ROOT% %LOCAL_WORK_DIR% %REMOTE_WORK_DIR%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	exit /b %result%
)
