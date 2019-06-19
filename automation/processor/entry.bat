@ECHO OFF
cmd /c "exit 0"

REM Action can be used to pass staging directory with staging@ prefix
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

IF "%BRANCH%" == "master" (
	GOTO StagingArtefacts
)

echo [%~nx0] Do not pass ACTION when executing non-master branch
call %CD%\automation\processor\buildPackage.bat %BUILDNUMBER% %BRANCH%
SET result=%ERRORLEVEL%
if %result% NEQ 0 (
	echo [%~nx0] ERROR call %CD%\automation\processor\buildPackage.bat %BUILDNUMBER% %BRANCH%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	echo.
    echo [%~nx0] --- End Targetless Branch CI Error Handling ---
	echo.
	exit /b %result%
)
GOTO BranchCheck

:StagingArtefacts
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

:BranchCheck
IF "%BRANCH%" == "master" (
	echo [%~nx0] Only perform container test in CI for branches, Master execution in CD pipeline
	GOTO BranchImageTest
)

IF "%BRANCH%" == "refs/heads/master" (
	echo [%~nx0] Only perform container test in CI for branches, Master execution in CD pipeline
	GOTO BranchImageTest
)

REM Do not call from within IF statement or errorlevel is lost
echo [%~nx0] Only perform container test in CI for branches, CD for branch %BRANCH%
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

:BranchImageTest
IF "%BRANCH_IMAGE_CLEAN%" == "" GOTO endOfScript
if NOT %BRANCH_IMAGE_CLEAN% == "yes" GOTO endOfScript

:GitClean
call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %cd%\%automationRoot%\processor\removeDockerImage.ps1 %ACTION%
set result=%errorlevel%
if %result% NEQ 0 (
	echo [%~nx0] BUILD_PACKAGE_ERROR call powershell -NoProfile -NonInteractive -ExecutionPolicy ByPass -command %cd%\%automationRoot%\processor\removeDockerImage.ps1 %ACTION%
	echo [%~nx0]   Return LASTEXITCODE %result% 
	exit /b %result%
)

:endOfScript
exit /b 0