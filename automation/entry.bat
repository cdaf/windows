@ECHO OFF
cmd /c "exit 0"

rem This script is for use with Git only and is dependent on "master" branch naming convention

rem Action can be used to pass staging directory with staging@ prefix or 
rem housekeeping with remoteURL@

set CDAF_COMMAND_SHELL=yes

for %%Q in ("%~dp0\.") DO set "AUTOMATIONROOT=%%~fQ"

echo.
echo [%~nx0] ----------------------------------
echo [%~nx0] PowerShell Execution Policy ByPass

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command "& '%AUTOMATIONROOT%\entry.ps1'" "'%1'" "'%2'" "'%3'" "'%4'"
set result=%errorlevel%
if %result% NEQ 0 (
	echo [%~nx0] DELIVERY_ERROR call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %AUTOMATIONROOT%\entry.ps1 %1 %2 %3 %4
	echo [%~nx0]   Return LASTEXITCODE %result% 
	exit /b %result%
)

echo [%~nx0] PowerShell Policy ByPass Complete
echo [%~nx0] ----------------------------------
echo.
exit 0