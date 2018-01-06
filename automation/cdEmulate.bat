@echo off
cmd /c "exit 0"

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
	echo [%~nx0] ERROR call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%automationRoot%\processor\cdEmulate.ps1 %ACTION% %AUTOMATION_ROOT%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	echo.
    echo [%~nx0] --- End Emulation Error Handling ---
	echo.
	exit /b %result%
)
