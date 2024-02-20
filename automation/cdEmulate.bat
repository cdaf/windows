@echo off
cmd /c "exit 0"

rem Too complicated to derive automation root from Batch runner, so hard coded for windows.
set ACTION=%1

echo.
echo [%~nx0] --------------------
echo [%~nx0] Initialise Emulation
echo [%~nx0] --------------------

for %%Q in ("%~dp0\.") DO set "AUTOMATIONROOT=%%~fQ"

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command "& '%AUTOMATIONROOT%\processor\cdEmulate.ps1'" "'%ACTION%'"
set result=%errorlevel%
if %result% NEQ 0 (
	echo [%~nx0] ERROR call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %AUTOMATIONROOT%\processor\cdEmulate.ps1 %ACTION%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	echo.
    echo [%~nx0] --- End Emulation Error Handling ---
	echo.
	exit /b %result%
)
