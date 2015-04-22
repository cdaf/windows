@echo off

set action=%1

rem Launcher script that overides execution policy
rem cannot elevate powershell, so this batch file must be run elevated

call powershell -ExecutionPolicy ByPass -command %cd%\sqlServerExpressTCP.ps1 %action%
REM **********************
REM warnings and exit codes
REM **********************
set exitFromPowershell=%errorLevel%
if not %exitFromPowershell%==0 goto exception

:Exit
echo [%0] ... test for project %project% complete.
echo.

exit /b %exitFromPowershell%

:exception
echo [%0] ... ended in error, exit %exitFromPowershell%
echo.

exit /b %exitFromPowershell%
