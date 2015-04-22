@echo off

set project=%1

echo.
echo [%0] Starting Remote Connection test for project %project%"
echo.

set target=%2

if NOT "%target%" == "" goto executeTest

echo [%0] Target not supplied, set to computername
set target=%computername%

:executeTest

rem Launcher script that overides execution policy
rem cannot elevate powershell, so this batch file must be run elevated

call powershell -ExecutionPolicy ByPass -command %cd%\test.ps1 %target%
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
