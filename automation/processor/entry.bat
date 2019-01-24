@ECHO OFF
cmd /c "exit 0"

REM Too complicated to derive automation root from Batch runner, so hard coded for windows.
SET BUILDNUMBER=%1
SET BRANCH=%2
SET ACTION=%3

echo.
echo [%~nx0] --------------------
echo [%~nx0] Targetless Branch CD
echo [%~nx0]   BUILDNUMBER : %BUILDNUMBER%
echo [%~nx0]   BRANCH      : %BRANCH%
echo [%~nx0]   ACTION      : %ACTION%

REM Launcher script that overides execution policy
REM cannot elevate powershell

call %CD%\automation\processor\buildPackage.bat %BUILDNUMBER% %BRANCH% %ACTION%
SET result=%ERRORLEVEL%
if %result% NEQ 0 (
	echo [%~nx0] ERROR call %CD%\automation\processor\buildPackage.bat %BUILDNUMBER% %BRANCH% %ACTION%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	echo.
    echo [%~nx0] --- End Targetless Branch CI Error Handling ---
	echo.
	exit /b %result%
)

IF "%BRANCH%" == "master" (
	echo [%~nx0] Only perform container test in CI for branches, Master execution in CD pipeline
	exit /b 0
) ELSE (
	GOTO :EXITNEST
)

# REM Do not call from within IF statement or errorlevel is lost
:EXITNEST
call %CD%\TasksLocal\delivery.bat DOCKER
SET result=%ERRORLEVEL%
if %result% NEQ 0 (
	echo [%~nx0] ERROR call %CD%\TasksLocal\delivery.bat DOCKER
	echo [%~nx0]   Return LASTEXITCODE %result% 
	echo.
    echo [%~nx0] --- End Targetless Branch CD Error Handling ---
	echo.
	exit /b %result%
)
