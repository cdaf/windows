
$scriptName = $myInvocation.MyCommand.Name

Write-Host
Write-Host "[$scriptName] +--------------------------------+"
Write-Host "[$scriptName] | Process Locally Executed Tasks |"
Write-Host "[$scriptName] +--------------------------------+"

$ENVIRONMENT = $args[0]
Write-Host "[$scriptName]   ENVIRONMENT            : $ENVIRONMENT" 
$BUILD = $args[1]
Write-Host "[$scriptName]   BUILD                  : $BUILD" 
$SOLUTION = $args[2]
Write-Host "[$scriptName]   SOLUTION               : $SOLUTION" 
$WORK_DIR_DEFAULT = $args[3]
Write-Host "[$scriptName]   WORK_DIR_DEFAULT       : $WORK_DIR_DEFAULT" 

$localPropertiesPath = 'propertiesForLocalTasks\'
$localPropertiesFilter = $localPropertiesPath + "$ENVIRONMENT*"
$localEnvironmentPath = 'propertiesForLocalEnvironment\'

# change to working directory
cd $WORK_DIR_DEFAULT

# Pre and Post traget processing tasks
$propertiesFile = "$localEnvironmentPath\$ENVIRONMENT"
if ( Test-Path $propertiesFile ) {
	try {
		$localEnvPreDeployTask=$(& .\getProperty.ps1 $propertiesFile "localEnvPreDeployTask")
		if(!$?){ taskWarning }
	} catch { exceptionExit 'GET_ENVIRONMENT_PRE_TASK_101' $_ }
	Write-Host "[$scriptName]   localEnvPreDeployTask  : $localEnvPreDeployTask" 
	
	try {
		$localEnvPostDeployTask=$(& .\getProperty.ps1 $propertiesFile "localEnvPostDeployTask")
		if(!$?){ taskWarning }
	} catch { exceptionExit 'GET_ENVIRONMENT_POST_TASK_102' $_ }
	Write-Host "[$scriptName]   localEnvPostDeployTask : $localEnvPostDeployTask" 

} else {

	Write-Host "[$scriptName]   localEnvironmentPath   : (not defined)" 

}

$propertiesFile = "CDAF.properties"
$propName = "productVersion"
try {
	$cdafVersion=$(& .\getProperty.ps1 $propertiesFile $propName)
	if(!$?){ taskWarning }
} catch { exceptionExit 'GET_CDAF_VERSION_103' $_ }

Write-Host "[$scriptName]   CDAF Version           : $cdafVersion"

# list system info
Write-Host "[$scriptName]   pwd                    : $(pwd)"
Write-Host "[$scriptName]   Hostname               : $(hostname)" 
Write-Host "[$scriptName]   Whoami                 : $(whoami)" 

$exitStatus = 0

# Perform Local Prepartion Tasks for this Environment 
if ( $localEnvPreDeployTask) {
    Write-Host
    # Execute the Tasks Driver File
    & .\execute.ps1 $SOLUTION $BUILD $localEnvironmentPath\$ENVIRONMENT $localEnvPreDeployTask
	if($LASTEXITCODE -ne 0){ passExitCode "LOCAL_TASKS_PRE_DEPLOY_NON_ZERO_EXIT .\execute.ps1 $SOLUTION $BUILD $localEnvironmentPath\$ENVIRONMENT $localEnvPreDeployTask" $LASTEXITCODE }
    if(!$?){ taskFailure "LOCAL_TASKS_PRE_DEPLOY_TRAP" }
}

# Perform Local Tasks for each target definition file for this environment
if (-not(Test-Path $localPropertiesFilter)) {

	Write-Host "[$scriptName] local properties not found ($localPropertiesFilter) assuming this is new implementation, no action attempted" -ForegroundColor Yellow

} else {

	# Load the environment target properties files to the root
	Copy-Item $localPropertiesFilter .

	Write-Host
	Write-Host "[$scriptName] Preparing to process targets :"
	Write-Host
	foreach ($propFile in (Get-ChildItem -Path $localPropertiesFilter)) {
		$propFilename = getFilename($propFile.ToString())
		Write-Host "[$scriptName]   $propFilename"
	}

	foreach ($propFile in (Get-ChildItem -Path $localPropertiesFilter)) {

		$propFilename = getFilename($propFile.ToString())

		write-host "`n[$scriptName]   --- Process Target $propFilename --- " -ForegroundColor Green
		& .\localTasksTarget.ps1 $ENVIRONMENT $SOLUTION $BUILD $propFilename
		if($LASTEXITCODE -ne 0){ passExitCode "LOCAL_NON_ZERO_EXIT & .\localTasksTarget.ps1 $ENVIRONMENT $SOLUTION $BUILD $propFilename" $LASTEXITCODE }
		if(!$?){ taskWarning }

		write-host "`n[$scriptName]   --- Completed Target $propFilename --- " -ForegroundColor Green
	}
}

# Perform Local Post Deploy Tasks for this Environment 
if ( $localEnvPostDeployTask) {
    Write-Host
    # Execute the Tasks Driver File
    & .\execute.ps1 $SOLUTION $BUILD $localEnvironmentPath\$ENVIRONMENT $localEnvPostDeployTask
	if($LASTEXITCODE -ne 0){ passExitCode "LOCAL_TASKS_POST_DEPLOY_NON_ZERO_EXIT .\execute.ps1 $SOLUTION $BUILD $localEnvironmentPath\$ENVIRONMENT $localEnvPostDeployTask" $LASTEXITCODE }
    if(!$?){ taskFailure "LOCAL_TASKS_POST_DEPLOY_TRAP" }
}

# Return to root
cd ..
