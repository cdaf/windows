@echo off

rem Too complicated to derive automation root from Batch runner, so hard coded for windows.
set ACTION=%1
set AUTOMATION_ROOT=%2

echo.
echo [%~nx0] --------------------
echo [%~nx0] Initialise Emulation
echo [%~nx0] --------------------

IF [%AUTOMATION_ROOT%] == [] (
	set automationRoot=automation
) else (
	set automationRoot=%AUTOMATION_ROOT%
)

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%automationRoot%\processor\cdEmulate.ps1 %ACTION% %AUTOMATION_ROOT%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] Error %result% returned from ... 
	echo [%~nx0]   call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%automationRoot%\processor\cdEmulate.ps1 %ACTION% %AUTOMATION_ROOT%
	echo.
    echo [%~nx0] --- Emulation Error Handling ---
	echo.
	exit /b %result%
)
