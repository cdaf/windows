
$scriptName = $myInvocation.MyCommand.Name

Write-Host "`n[$scriptName] +--------------------------------+"
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
$OPT_ARG = $args[4]
Write-Host "[$scriptName]   OPT_ARG                : $OPT_ARG" 

$propertiesFilter = 'propertiesForLocalTasks\' + "$ENVIRONMENT*"
$localEnvironmentPath = 'propertiesForLocalEnvironment\'

# change to working directory
cd $WORK_DIR_DEFAULT
$WORK_DIR_DEFAULT = (Get-Location).Path

# Pre and Post traget processing tasks
$propertiesFile = "$localEnvironmentPath\$ENVIRONMENT"
if ( Test-Path $propertiesFile ) {
	try {
		$localEnvPreDeployTask=$(& ${WORK_DIR_DEFAULT}\getProperty.ps1 $propertiesFile "localEnvPreDeployTask")
		if(!$?){ taskWarning }
	} catch { exceptionExit 'GET_ENVIRONMENT_PRE_TASK_101' $_ }
	Write-Host "[$scriptName]   localEnvPreDeployTask  : $localEnvPreDeployTask" 
	
	try {
		$localEnvPostDeployTask=$(& ${WORK_DIR_DEFAULT}\getProperty.ps1 $propertiesFile "localEnvPostDeployTask")
		if(!$?){ taskWarning }
	} catch { exceptionExit 'GET_ENVIRONMENT_POST_TASK_102' $_ }
	Write-Host "[$scriptName]   localEnvPostDeployTask : $localEnvPostDeployTask" 

} else {

	Write-Host "[$scriptName]   localEnvironmentPath   : (not defined)" 

}

$propertiesFile = "CDAF.properties"
$propName = "productVersion"
try {
	$cdafVersion=$(& ${WORK_DIR_DEFAULT}\getProperty.ps1 $propertiesFile $propName)
	if(!$?){ taskWarning }
} catch { exceptionExit 'GET_CDAF_VERSION_103' $_ }

Write-Host "[$scriptName]   CDAF Version           : $cdafVersion"

# list system info
Write-Host "[$scriptName]   Hostname               : $(hostname)" 
Write-Host "[$scriptName]   Whoami                 : $(whoami)" 
Write-Host "[$scriptName]   pwd                    : $(pwd)"

$exitStatus = 0

# Perform Local Preparation Tasks for this Environment 
if ( $localEnvPreDeployTask) {
    Write-Host
    # Execute the Tasks Driver File
    & ${WORK_DIR_DEFAULT}\execute.ps1 $SOLUTION $BUILD $localEnvironmentPath\$ENVIRONMENT $localEnvPreDeployTask $OPT_ARG
	if($LASTEXITCODE -ne 0){ ERRMSG "LOCAL_TASKS_PRE_DEPLOY_NON_ZERO_EXIT ${WORK_DIR_DEFAULT}\execute.ps1 $SOLUTION $BUILD $localEnvironmentPath\$ENVIRONMENT $localEnvPreDeployTask" $LASTEXITCODE }
    if(!$?){ taskFailure "LOCAL_TASKS_PRE_DEPLOY_TRAP" }
}

# Perform Local Tasks for each target definition file for this environment
if (-not(Test-Path $propertiesFilter)) {

	Write-Host "`n[$scriptName][WARN] Properties not found ($propertiesFilter) alter processSequence property to skip" -ForegroundColor Yellow

} else {

	# Load the environment target properties files to the root
	Copy-Item $propertiesFilter .

	Write-Host "`n[$scriptName] Preparing to process targets :`n"
	foreach ($propFile in (Get-ChildItem -Path $propertiesFilter)) {
		$propFilename = getFilename($propFile.ToString())
		Write-Host "[$scriptName]   $propFilename"
	}

	foreach ($propFile in (Get-ChildItem -Path $propertiesFilter)) {

		$propFilename = getFilename($propFile.ToString())

		write-host "`n[$scriptName]   --- Process Target $propFilename --- " -ForegroundColor Green
		& ${WORK_DIR_DEFAULT}\localTasksTarget.ps1 $ENVIRONMENT $SOLUTION $BUILD $propFilename $OPT_ARG
		if($LASTEXITCODE -ne 0){ ERRMSG "LOCAL_NON_ZERO_EXIT & ${WORK_DIR_DEFAULT}\localTasksTarget.ps1 $ENVIRONMENT $SOLUTION $BUILD $propFilename" $LASTEXITCODE }
		if(!$?){ taskWarning }

		write-host "`n[$scriptName]   --- Completed Target $propFilename --- " -ForegroundColor Green
	}
}

# Perform Local Post Deploy Tasks for this Environment 
if ( $localEnvPostDeployTask) {
    Write-Host
    # Execute the Tasks Driver File
    & ${WORK_DIR_DEFAULT}\execute.ps1 $SOLUTION $BUILD $localEnvironmentPath\$ENVIRONMENT $localEnvPostDeployTask $OPT_ARG
	if($LASTEXITCODE -ne 0){ ERRMSG "LOCAL_TASKS_POST_DEPLOY_NON_ZERO_EXIT ${WORK_DIR_DEFAULT}\execute.ps1 $SOLUTION $BUILD $localEnvironmentPath\$ENVIRONMENT $localEnvPostDeployTask" $LASTEXITCODE }
    if(!$?){ taskFailure "LOCAL_TASKS_POST_DEPLOY_TRAP" }
}

# Return to root
cd ..
