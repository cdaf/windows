@echo off

rem Emulate calling the package and deploy process as it would be from the automation toolset, 
rem e.g. Bamboo or Jenkings, replacing BUILD with timestamp
rem workspace with temp space. The variables provided in Jenkins are emulated in the scripts
rem themselves, that way the scripts remain portable, i.e. can be used in other CI tools.

set ACTION=%1

rem Automation Toolset Values
for %%* in (.) do set CurrDirName=%%~n*
set SOLUTION=%CurrDirName%

set timefmt=%time%
set timefmt=%TIMEFMT:~0,2%%TIMEFMT:~3,2%%TIMEFMT:~6,2%
set timefmt=%TIMEFMT: =0%

if DEFINED CD_ENV (
	set ENVIRONMENT=%CD_ENV%
) else (
	set ENVIRONMENT=DEV
)

set BUILD=%DATE:~-4%%DATE:~7,2%%DATE:~4,2%%timefmt%
set REVISION=66

rem User Defined Values
set automationRoot=automation
set LOCAL_WORK_DIR=TasksLocal
set REMOTE_WORK_DIR=TasksRemote

echo.
echo [%~nx0] ===========================================
echo [%~nx0] Continuous Delivery (CD) Emulation Starting
echo [%~nx0]           CDAF Version : 0.7.4
echo [%~nx0] ===========================================
echo [%~nx0]   ACTION      : %ACTION%
echo [%~nx0]   ENVIRONMENT : %ENVIRONMENT%
echo.
if NOT "%ACTION%" == "clean" (

	echo [%~nx0] ---------- Build Toolset Configuration Guide ----------
	echo.
    echo [%~nx0] For TeamCity ...
    echo Command Executable : %automationRoot%\buildandpackage\buildProjects.bat 
    echo Command parameters : %SOLUTION% %%build.number%% %%build.vcs.number%% BUILD
    echo.
    echo [%~nx0] For Bamboo ...
    echo Script file : %automationRoot%\buildandpackage\buildProjects.bat
    echo Argument : %SOLUTION% ${bamboo.buildNumber} ${bamboo.repository.revision.number} BUILD
    echo.
    echo [%~nx0] For Jenkins ...
    echo Command : %automationRoot%\buildandpackage\buildProjects.bat %SOLUTION% %%BUILD_NUMBER%% %%SVN_REVISION%% BUILD
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
call "%cd%\%automationRoot%\buildandpackage\buildProjects.bat" %SOLUTION% %BUILD% %REVISION% %ENVIRONMENT% %ACTION%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] call "%cd%\%automationRoot%\buildandpackage\buildProjects.bat" %SOLUTION% %BUILD% %REVISION% %ENVIRONMENT% %ACTION% failed!
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)

if NOT "%ACTION%" == "clean" (

	echo [%~nx0] ---------- Package Toolset Configuration Guide ----------
	echo.
    echo [%~nx0] For TeamCity ...
    echo Command Executable : %automationRoot%\buildandpackage\package.bat 
    echo Command parameters : %SOLUTION% %%build.number%% %%build.vcs.number%% %LOCAL_WORK_DIR% %REMOTE_WORK_DIR%
    echo.
    echo [%~nx0] For Bamboo ...
    echo Script file : %automationRoot%\buildandpackage\package.bat
    echo Argument : %SOLUTION% ${bamboo.buildNumber} ${bamboo.repository.revision.number} %LOCAL_WORK_DIR% %REMOTE_WORK_DIR%
    echo.
    echo [%~nx0] For Jenkins ...
    echo Command : %automationRoot%\buildandpackage\package.bat %SOLUTION% %%BUILD_NUMBER%% %%SVN_REVISION%% %LOCAL_WORK_DIR% %REMOTE_WORK_DIR%
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

call "%cd%\%automationRoot%\buildandpackage\package.bat" %SOLUTION% %BUILD% %REVISION% %LOCAL_WORK_DIR% %REMOTE_WORK_DIR% %ACTION%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] call "%cd%\%automationRoot%\buildandpackage\package.bat" %SOLUTION% %BUILD% %REVISION% %ACTION% failed!
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)

if "%ACTION%" == "clean" (
	echo.
	echo [%~nx0] done, cleaned workspace only for action %ACTION%
    goto end
)

if "%ACTION%" == "notasks" (
	echo.
	echo [%~nx0] build and package only for action %ACTION%
    goto end
)

if "%ACTION%" == "local" (
	echo.
	echo [%~nx0] perform local tasks only for action %ACTION%
    goto localTasks
)

echo.
echo [%~nx0] ============================
echo [%~nx0] Transition to Task Execution
echo [%~nx0] ============================
echo.
echo [%~nx0] ---------- Remote Task Execution ----------
echo.
echo [%~nx0] For TeamCity ...
echo Command Executable : \%LOCAL_WORK_DIR%\remoteTasks.bat 
echo Command parameters : %ENVIRONMENT% %%build.number%% %SOLUTION% %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For Bamboo ...
echo Script file : ${bamboo.build.working.directory}\%LOCAL_WORK_DIR%\remoteTasks.bat
echo Argument : ${bamboo.deploy.environment} ${bamboo.buildNumber} ${bamboo.deploy.project} %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For Jenkins ...
echo Command : \%LOCAL_WORK_DIR%\remoteTasks.bat %ENVIRONMENT% %%BUILD_NUMBER%% %SOLUTION% %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For Team Foundation Server ...
echo Command Filename : SourcesDirectory + "\%LOCAL_WORK_DIR%\remoteTasks.bat"
echo Command arguments : %ENVIRONMENT% + " " + BuildDetail.BuildNumber + " " + %SOLUTION% + " " + %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For BuildMaster ...
echo Executable file : \%LOCAL_WORK_DIR%\remoteTasks.bat 
echo Arguments : %SOLUTION% + " ${BuildNumber} " + %SOLUTION% + " " + %LOCAL_WORK_DIR%
echo.
echo [%~nx0] -------------------------------------------
echo.
call "%cd%\%LOCAL_WORK_DIR%\remoteTasks.bat" %ENVIRONMENT% %BUILD% %SOLUTION% %LOCAL_WORK_DIR%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] call "%cd%\%LOCAL_WORK_DIR%\remoteTasks.bat" %ENVIRONMENT% %BUILD% %SOLUTION% %LOCAL_WORK_DIR% failed!
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)

:localTasks
echo.
echo [%~nx0] ---------- Local Task Execution ----------
echo.
echo [%~nx0] For TeamCity ...
echo Command Executable : \%LOCAL_WORK_DIR%\localTasks.bat 
echo Command parameters : %ENVIRONMENT% %%build.number%% %SOLUTION% %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For Bamboo ...
echo Script file : ${bamboo.build.working.directory}\%LOCAL_WORK_DIR%\localTasks.bat
echo Argument : ${bamboo.deploy.environment} ${bamboo.buildNumber} ${bamboo.deploy.project} %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For Jenkins ...
echo Command : \%LOCAL_WORK_DIR%\localTasks.bat %ENVIRONMENT% %%BUILD_NUMBER%% %SOLUTION% %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For Team Foundation Server ...
echo Command Filename : SourcesDirectory + "\%LOCAL_WORK_DIR%\localTasks.bat"
echo Command arguments : %ENVIRONMENT% + " " + BuildDetail.BuildNumber + " " + %SOLUTION% + " " + %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For BuildMaster ...
echo Executable file : \%LOCAL_WORK_DIR%\localTasks.bat 
echo Arguments : %SOLUTION% + " ${BuildNumber} " + %SOLUTION% + " " + %LOCAL_WORK_DIR%
echo.
echo [%~nx0] -------------------------------------------
echo.
call "%cd%\%LOCAL_WORK_DIR%\localTasks.bat" %ENVIRONMENT% %BUILD% %SOLUTION% %LOCAL_WORK_DIR%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] all "%cd%\%LOCAL_WORK_DIR%\localTasks.bat" %ENVIRONMENT% %BUILD% %SOLUTION% %LOCAL_WORK_DIR% failed!
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)

:end
echo.
echo [%~nx0] ===========================================
echo [%~nx0] Continuous Delivery (CD) Emulation Complete
echo [%~nx0] ===========================================
echo.
