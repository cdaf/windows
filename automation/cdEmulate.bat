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

rem Convert double quotes to single quotes so arguments containing spaces survive the -command string
set "CDAF_ARGS=%*"
if defined CDAF_ARGS set CDAF_ARGS=%CDAF_ARGS:"='%

call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command "& '%AUTOMATIONROOT%\processor\cdEmulate.ps1' %CDAF_ARGS%"
set result=%errorlevel%
if %result% NEQ 0 (
	echo [%~nx0] ERROR call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %AUTOMATIONROOT%\processor\cdEmulate.ps1 %CDAF_ARGS%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	echo.
    echo [%~nx0] --- End Emulation Error Handling ---
	echo.
	exit /b %result%
)
