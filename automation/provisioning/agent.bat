@echo off

set targetHost=%1
set userID=%2
set outputFile=%3

rem Launcher script that overides execution policy
rem cannot elevate powershell, so this batch file must be run elevated

REM *********************************************************
REM Execute PowerShell, exceptions are converted to exit code
REM *********************************************************

call powershell -ExecutionPolicy ByPass -command %cd%\agent.ps1 %targetHost% %userID% %outputFile%
set exitFromPowershell=%errorLevel%
if not %exitFromPowershell%==0 goto exception

:Exit
echo [%0] ... complete.
echo.

exit /b %exitFromPowershell%

:exception
echo [%0] ... ended in error, exit %exitFromPowershell%
echo.

exit /b %exitFromPowershell%
