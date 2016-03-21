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
echo [%~nx0] Continuous Delivery (CD) Emulation Starting
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
echo [%~nx0] ---------------------
echo [%~nx0] Remote Task Execution
echo [%~nx0] ---------------------
echo.
echo [%~nx0] ---------- CD Toolset Configuration Guide -------------
echo.
echo Note: artifact retention typically does include file attribute for executable, so
echo  set the first step of deploy process to make all scripts executable
echo  chmod +x ./*/*.sh
echo.
echo [%~nx0] For TeamCity ...
echo   Command Executable : \%LOCAL_WORK_DIR%\remoteTasks.bat 
echo   Command parameters : %ENVIRONMENT% %%build.number%% %SOLUTION% %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For Bamboo ... (Beware! set Deployment project name to solution name, with no spaces)
echo Script file : ${bamboo.build.working.directory}\%LOCAL_WORK_DIR%\remoteTasks.bat
echo Argument : ${bamboo.deploy.environment} ${bamboo.buildNumber} ${bamboo.deploy.project} %LOCAL_WORK_DIR%
echo.
echo   note: set the release tag to (assuming no releases performed, otherwise, use the release number already set)
echo   build-${bamboo.buildNumber} deploy-1
echo.
echo [%~nx0] For Jenkins ...
echo Command : \%LOCAL_WORK_DIR%\remoteTasks.bat %ENVIRONMENT% %%BUILD_NUMBER%% %SOLUTION% %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For Team Foundation Server (XAML) ...
echo Command Filename  : SourcesDirectory + "\%LOCAL_WORK_DIR%\remoteTasks.bat"
echo Command arguments : %ENVIRONMENT% + " " + BuildDetail.BuildNumber + " " + %SOLUTION% + " " + %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For Team Foundation Server (vNext) ...
echo Command Filename  : $(System.DefaultWorkingDirectory)\<BuildDefinition>/TasksLocal/TasksLocal/localTasks.bat
echo Command arguments : %RELEASE_ENVIRONMENTNAME% %BUILD_BUILDNUMBER% cdaf TasksLocal
echo Working folder    : $(System.DefaultWorkingDirectory)\<BuildDefinition>/TasksLocal
echo.
echo For BuildMaster ...
echo Executable file : %LOCAL_WORK_DIR%\remoteTasks.bat 
echo Arguments : %ENVIRONMENT% ${BuildNumber} %SOLUTION% %LOCAL_WORK_DIR%
echo.
echo [%~nx0] -------------------------------------------------------
echo.
call "%cd%\%LOCAL_WORK_DIR%\remoteTasks.bat" %ENVIRONMENT% %BUILD% %SOLUTION% %LOCAL_WORK_DIR%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] call "%cd%\%LOCAL_WORK_DIR%\remoteTasks.bat" %ENVIRONMENT% %BUILD% %SOLUTION% %LOCAL_WORK_DIR% failed!
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)
echo.
echo [%~nx0] --------------------
echo [%~nx0] Local Task Execution
echo [%~nx0] --------------------
echo.
echo [%~nx0] ---------- CD Toolset Configuration Guide -------------
echo.
echo [%~nx0] For TeamCity ...
echo Command Executable : \%LOCAL_WORK_DIR%\localTasks.bat 
echo Command parameters : %ENVIRONMENT% %%build.number%% %SOLUTION% %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For Bamboo ... (Beware! set Deployment project name to solution name, with no spaces)
echo Script file : ${bamboo.build.working.directory}\%LOCAL_WORK_DIR%\localTasks.bat
echo Argument : ${bamboo.deploy.environment} ${bamboo.buildNumber} ${bamboo.deploy.project} %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For Jenkins ...
echo Command : \%LOCAL_WORK_DIR%\localTasks.bat %ENVIRONMENT% %%BUILD_NUMBER%% %SOLUTION% %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For Team Foundation Server (XAML) ...
echo Command Filename  : SourcesDirectory + "\%LOCAL_WORK_DIR%\localTasks.bat"
echo Command arguments : %ENVIRONMENT% + " " + BuildDetail.BuildNumber + " " + %SOLUTION% + " " + %LOCAL_WORK_DIR%
echo.
echo [%~nx0] For Team Foundation Server (vNext) ...
echo Command Filename  : $(System.DefaultWorkingDirectory)\<BuildDefinition>/TasksLocal/TasksLocal/remoteTasks.bat
echo Command arguments : %RELEASE_ENVIRONMENTNAME% %BUILD_BUILDNUMBER% cdaf TasksRemote
echo Working folder    : $(System.DefaultWorkingDirectory)\<BuildDefinition>/TasksLocal
echo.
echo [%~nx0] For BuildMaster ...
echo Executable file : %LOCAL_WORK_DIR%\localTasks.bat 
echo Arguments : %ENVIRONMENT% ${BuildNumber} %SOLUTION% %LOCAL_WORK_DIR%
echo.
echo [%~nx0] -------------------------------------------------------
echo.
call "%cd%\%LOCAL_WORK_DIR%\localTasks.bat" %ENVIRONMENT% %BUILD% %SOLUTION% %LOCAL_WORK_DIR%
set result=%errorlevel%
if %result% NEQ 0 (
	echo.
	echo [%~nx0] all "%cd%\%LOCAL_WORK_DIR%\localTasks.bat" %ENVIRONMENT% %BUILD% %SOLUTION% %LOCAL_WORK_DIR% failed!
	echo [%~nx0] Errorlevel = %result%
	exit /b %result%
)
