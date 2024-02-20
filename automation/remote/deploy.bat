@echo off
echo [%~nx0] ExecutionPolicy ByPass ...

echo.
echo [%~nx0] ------------------------------------
echo [%~nx0]   Remote Execution Policy Override
echo [%~nx0] ------------------------------------

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command "& '%cd%\%WORK_DIR_DEFAULT%\executeTasks.ps1' "%1" "%2" "%3"
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] CDAF_DELIVERY_FAILURE call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %cd%\%WORK_DIR_DEFAULT%\executeTasks.ps1 "%1" "%2" "%3"
	echo [%~nx0]   Return LASTEXITCODE %result% 
	exit /b %result%
)

echo.
echo [%~nx0] ------------------------------------
echo [%~nx0]        Deployment Complete
echo [%~nx0] ------------------------------------
