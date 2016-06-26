@echo off

set ENVIRONMENT=%1
set BUILD=%2
set SOLUTION=%3
set WORK_DIR_DEFAULT=%4
echo.
echo [%~nx0] ------------------
echo [%~nx0]   Local Process
echo [%~nx0] ------------------

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%WORK_DIR_DEFAULT%\localTasks.ps1 %ENVIRONMENT% %BUILD% %SOLUTION% %WORK_DIR_DEFAULT%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%WORK_DIR_DEFAULT%\localTasks.ps1 %ENVIRONMENT% %BUILD% %SOLUTION% %WORK_DIR_DEFAULT% failed!
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)
