@echo off

set userCred=%1
set outFile=%2
set testHost=%3

rem Launcher script that overides execution policy
rem cannot elevate powershell, so this batch file must be run elevated

call powershell -ExecutionPolicy ByPass -command %cd%\remotePowershellStoredCredentials.ps1 "%userCred%" "%outFile%" "%testHost%"
REM **********************
REM warnings and exit codes
REM **********************
set exitFromPowershell=%errorLevel%
if not %exitFromPowershell%==0 goto exception

:Exit
echo [%0] complete.
echo.

exit /b %exitFromPowershell%

:exception
echo [%0] Error! Exit %exitFromPowershell%
echo.

exit /b %exitFromPowershell%
