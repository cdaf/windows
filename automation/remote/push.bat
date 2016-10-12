@echo off
echo [%0] Push to NuGet URL ...

set PACKAGE_LOC=%1
set KEY_FILE=%2
set URL=%3
echo.
echo [%~nx0] ------------------
echo [%~nx0]   Local Process
echo [%~nx0] ------------------
echo [%~nx0]   PACKAGE_LOC : %PACKAGE_LOC%
echo [%~nx0]   KEY_FILE    : %KEY_FILE%
echo [%~nx0]   URL         : %URL%

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%WORK_DIR_DEFAULT%\automation\local\push.ps1 %PACKAGE_LOC% %KEY_FILE% %URL%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] Error %result% returned from ... 
	echo [%~nx0]   call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%WORK_DIR_DEFAULT%\automation\local\push.ps1 %PACKAGE_LOC% %KEY_FILE% %URL%
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)
