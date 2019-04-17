@echo off
echo.
echo [%~nx0] ------------------------
echo [%~nx0] PowerShell Script Runner
echo [%~nx0] ------------------------

rem Launcher script that overides execution policy
rem cannot elevate powershell

set "back=\"
set "command=%cd%%back%%1"

echo %command% %2 %3 %4 %5 %6 %7 %8 %9

call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %command% %2 %3 %4 %5 %6 %7 %8 %9 
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %command% %2 %3 %4 %5 %6 %7 %8 %9 failed!
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)
