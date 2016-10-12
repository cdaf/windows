
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
	} catch { taskFailure "GET_ENVIRONMENT_PRE_TASK_101" }
	Write-Host "[$scriptName]   localEnvPreDeployTask  : $localEnvPreDeployTask" 
	
	try {
		$localEnvPostDeployTask=$(& .\getProperty.ps1 $propertiesFile "localEnvPostDeployTask")
		if(!$?){ taskWarning }
	} catch { taskFailure "GET_ENVIRONMENT_POST_TASK_102" }
	Write-Host "[$scriptName]   localEnvPostDeployTask : $localEnvPostDeployTask" 

} else {

	Write-Host "[$scriptName]   localEnvironmentPath   : (not defined)" 

}

$propertiesFile = "CDAF.properties"
$propName = "productVersion"
try {
	$cdafVersion=$(& .\getProperty.ps1 $propertiesFile $propName)
	if(!$?){ taskWarning }
} catch { taskFailure "GET_CDAF_VERSION_103" }
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
    try {
	    & .\execute.ps1 $SOLUTION $BUILD $localEnvironmentPath\$ENVIRONMENT $localEnvPreDeployTask
	    if(!$?){ taskFailure "EXECUTE_TRAP_200" }
    } catch { taskFailure "EXECUTE_EXCEPTION_201" }
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

		Write-Host
		write-host "[$scriptName]   --- Process Target $propFilename --- " -ForegroundColor Green
		try {
			& .\localTasksTarget.ps1 $ENVIRONMENT $SOLUTION $BUILD $propFilename
			if(!$?){ taskWarning }
		} catch { taskFailure "${propFilename}_202" }
		Write-Host
		write-host "[$scriptName]   --- Completed Target $propFilename --- " -ForegroundColor Green
	}
}

# Perform Local Post Deploy Tasks for this Environment 
if ( $localEnvPostDeployTask) {
    Write-Host
    # Execute the Tasks Driver File
    try {
	    & .\execute.ps1 $SOLUTION $BUILD $localEnvironmentPath\$ENVIRONMENT $localEnvPostDeployTask
	    if(!$?){ taskFailure "EXECUTE_TRAP_210" }
    } catch { taskFailure "EXECUTE_EXCEPTION_211"}
}

# Return to root
cd ..
