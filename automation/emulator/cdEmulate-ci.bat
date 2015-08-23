@echo off

rem Emulate calling the package and deploy process as it would be from the automation toolset, 
rem e.g. Bamboo or Jenkings, replacing BUILD with timestamp
rem workspace with temp space. The variables provided in Jenkins are emulated in the scripts
rem themselves, that way the scripts remain portable, i.e. can be used in other CI tools.

set SOLUTION=%1
set ENVIRONMENT=%2
set BUILD=%3
set REVISION=%4
set AUTOMATION_ROOT=%5
set LOCAL_WORK_DIR=%6
set REMOTE_WORK_DIR=%7
set ACTION=%8

echo.
echo [%~nx0] ==============================================
echo [%~nx0] Continuous Integration (CI) Emulation Starting
echo [%~nx0] ==============================================
echo [%~nx0]   SOLUTION        : %SOLUTION%
echo [%~nx0]   ENVIRONMENT     : %ENVIRONMENT%
echo [%~nx0]   BUILD           : %BUILD%
echo [%~nx0]   REVISION        : %REVISION%
echo [%~nx0]   AUTOMATION_ROOT : %AUTOMATION_ROOT%
echo [%~nx0]   LOCAL_WORK_DIR  : %LOCAL_WORK_DIR%
echo [%~nx0]   REMOTE_WORK_DIR : %REMOTE_WORK_DIR%
echo [%~nx0]   ACTION          : %ACTION%
echo.
if NOT "%ACTION%" == "clean" (

	echo [%~nx0] ---------- CI Toolset Configuration Guide -------------
	echo.
    echo [%~nx0] For TeamCity ...
    echo Command Executable : %AUTOMATION_ROOT%\buildandpackage\buildProjects.bat 
    echo Command parameters : %SOLUTION% %%build.number%% %%build.vcs.number%% BUILD
    echo.
    echo [%~nx0] For Bamboo ...
    echo Script file : %AUTOMATION_ROOT%\buildandpackage\buildProjects.bat
    echo Argument : %SOLUTION% ${bamboo.buildNumber} ${bamboo.repository.revision.number} BUILD
    echo.
    echo [%~nx0] For Jenkins ...
    echo Command : %AUTOMATION_ROOT%\buildandpackage\buildProjects.bat %SOLUTION% %%BUILD_NUMBER%% %%SVN_REVISION%% BUILD
    echo.
    echo [%~nx0] For Team Foundation Server ...
    echo Command Filename : SourcesDirectory + "\automation\buildandpackage\buildProjects.bat"
    echo Command arguments : %SOLUTION% + " " + BuildDetail.BuildNumber + " " + revision + " BUILD"
    echo.
    echo [%~nx0] For BuildMaster ...
    echo Executable file  : SourcesDirectory + "\automation\buildandpackage\package.bat"
    echo Arguments : %SOLUTION% ${BuildNumber} revision BUILD
    echo.
	echo [%~nx0] -------------------------------------------------------
	echo.
)
call "%cd%\%AUTOMATION_ROOT%\buildandpackage\buildProjects.bat" %SOLUTION% %BUILD% %REVISION% %ENVIRONMENT% %ACTION%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] call "%cd%\%AUTOMATION_ROOT%\buildandpackage\buildProjects.bat" %SOLUTION% %BUILD% %REVISION% %ENVIRONMENT% %ACTION% failed!
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)

if NOT "%ACTION%" == "clean" (

	echo [%~nx0] ---------- CI Toolset Configuration Guide -------------
	echo.
    echo [%~nx0] For TeamCity ...
    echo Command Executable : %AUTOMATION_ROOT%\buildandpackage\package.bat 
    echo Command parameters : %SOLUTION% %%build.number%% %%build.vcs.number%% %LOCAL_WORK_DIR% %REMOTE_WORK_DIR%
    echo.
    echo [%~nx0] For Bamboo ...
    echo Script file : %AUTOMATION_ROOT%\buildandpackage\package.bat
    echo Argument : %SOLUTION% ${bamboo.buildNumber} ${bamboo.repository.revision.number} %LOCAL_WORK_DIR% %REMOTE_WORK_DIR%
    echo.
    echo [%~nx0] For Jenkins ...
    echo Command : %AUTOMATION_ROOT%\buildandpackage\package.bat %SOLUTION% %%BUILD_NUMBER%% %%SVN_REVISION%% %LOCAL_WORK_DIR% %REMOTE_WORK_DIR%
    echo.
    echo [%~nx0] For Team Foundation Server ...
    echo Command Filename : SourcesDirectory + "\automation\buildandpackage\package.bat"
    echo Command arguments : %SOLUTION% + " " + BuildDetail.BuildNumber + " " + revision + " " + %LOCAL_WORK_DIR% + " " + %REMOTE_WORK_DIR%
    echo.
    echo [%~nx0] For BuildMaster ...
    echo Executable file  : SourcesDirectory + "\automation\buildandpackage\package.bat"
    echo Arguments : %SOLUTION% ${BuildNumber} revision %LOCAL_WORK_DIR% %REMOTE_WORK_DIR%
    echo.
	echo [%~nx0] -------------------------------------------------------
	echo.
)

call "%cd%\%AUTOMATION_ROOT%\buildandpackage\package.bat" %SOLUTION% %BUILD% %REVISION% %LOCAL_WORK_DIR% %REMOTE_WORK_DIR% %ACTION%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] call "%cd%\%AUTOMATION_ROOT%\buildandpackage\package.bat" %SOLUTION% %BUILD% %REVISION% %ACTION% failed!
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)

if "%ACTION%" == "clean" (
	echo.
	echo [%~nx0] done, cleaned workspace only for action %ACTION%
)
