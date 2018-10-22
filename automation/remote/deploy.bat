@echo off
echo [%~nx0] ExecutionPolicy ByPass ...

set TARGET=%1
set WORKSPACE=%2
set OPT_ARG=%3

echo.
echo [%~nx0] ------------------------------------
echo [%~nx0]   Remote Execution Policy Override
echo [%~nx0] ------------------------------------

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%WORK_DIR_DEFAULT%\executeTasks.ps1 %TARGET% %WORKSPACE% %OPT_ARG%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] DEPLOY_ERROR call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%WORK_DIR_DEFAULT%\executeTasks.ps1 %TARGET% %WORKSPACE% %OPT_ARG%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	exit /b %result%
)
