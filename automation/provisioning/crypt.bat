@echo off

set outFile=%1

rem Launcher script that overides execution policy
rem cannot elevate powershell, so this batch file must be run elevated

call powershell -ExecutionPolicy ByPass -command %cd%\crypt.ps1 "%outFile%"
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
