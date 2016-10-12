@echo off
echo [%~nx0] ExecutionPolicy ByPass ...

set TARGET=%1
set WORKSPACE=%2

echo.
echo [%~nx0] ------------------------------------
echo [%~nx0]   Remote Execution Policy Override
echo [%~nx0] ------------------------------------

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%WORK_DIR_DEFAULT%\executeTasks.ps1 %TARGET% %WORKSPACE%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] Error %result% returned from ... 
	echo [%~nx0]   call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%WORK_DIR_DEFAULT%\executeTasks.ps1 %TARGET% %WORKSPACE% failed!
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)
