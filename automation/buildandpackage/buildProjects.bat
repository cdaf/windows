@echo off

set SOLUTION=%1
set BUILDNUMBER=%2
set REVISION=%3
set ENVIRONMENT=%4
set ACTION=%5
set automationRoot=automation

echo [%~nx0] ----------------------------------------
echo [%~nx0] Build all projects in projects.list file
echo [%~nx0] ----------------------------------------
echo [%~nx0]   SOLUTION       : %SOLUTION%
echo [%~nx0]   BUILDNUMBER    : %BUILDNUMBER%
echo [%~nx0]   REVISION       : %REVISION%
echo [%~nx0]   ENVIRONMENT    : %ENVIRONMENT%
echo [%~nx0]   ACTION         : %ACTION%

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%automationRoot%\buildandpackage\buildProjects.ps1 %SOLUTION% %BUILDNUMBER% %REVISION% %ENVIRONMENT% %automationRoot% %ACTION%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%automationRoot%\buildandpackage\buildProjects.ps1 %SOLUTION% %BUILDNUMBER% %REVISION% %ENVIRONMENT% %automationRoot% %ACTION% failed!
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)
