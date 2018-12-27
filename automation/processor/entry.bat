@echo off
cmd /c "exit 0"

rem Too complicated to derive automation root from Batch runner, so hard coded for windows.
set BUILDNUMBER=%1
set BRANCH=%2

echo.
echo [%~nx0] --------------------
echo [%~nx0] Initialise Emulation
echo [%~nx0] --------------------

rem Launcher script that overides execution policy
rem cannot elevate powershell

call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\automation\processor\buildPackage.bat %BUILDNUMBER% %BRANCH%
set result=%errorlevel%
if %result% NEQ 0 (
	echo [%~nx0] ERROR call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\automation\processor\buildPackage.bat %BUILDNUMBER% %BRANCH%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	echo.
    echo [%~nx0] --- End Emulation Error Handling ---
	echo.
	exit /b %result%
)

IF %BRANCH% NEQ master (
	call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\TasksLocal\delivery.bat DOCKER
	set result=%errorlevel%
	if %result% NEQ 0 (
		echo [%~nx0] ERROR call powershell -NoProfile -ExecutionPolicy ByPass -command %cd%\TasksLocal\delivery.bat BRANCHBUILD
		echo [%~nx0]   Return LASTEXITCODE %result% 
		echo.
	    echo [%~nx0] --- End Emulation Error Handling ---
		echo.
		exit /b %result%
	)
) ELSE (
	echo [%~nx0] Only perform container test in CI for branches, Master execution in CD pipeline
)