@echo off

set ACTION=%1
set automationRoot=automation
echo.
echo [%~nx0] --------------------
echo [%~nx0] Initialise Emulation
echo [%~nx0] --------------------
echo [%~nx0]   ACTION              : %ACTION%
echo [%~nx0]   automationRoot      : %automationRoot%

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%automationRoot%\emulator\cdEmulate.ps1 %automationRoot% %ACTION%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\%automationRoot%\emulator\cdEmulate.ps1 %automationRoot% %ACTION% failed!
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)
