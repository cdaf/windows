function exitWithCode ($taskName, $dosExit) {
    write-host
    write-host "[$scriptName] $taskName failed!" -ForegroundColor Red
    write-host
    write-host "     Returning errorlevel ($dosExit) to DOS" -ForegroundColor Magenta
    write-host
    $host.SetShouldExit($dosExit)
    exit
}

function taskWarning { 
    write-host "[$scriptName] Warning, $taskName encountered an error that was allowed to proceed." -ForegroundColor Yellow
}

function getFilename ($FullPathName) {

	$PIECES=$FullPathName.split(“\”) 
	$NUMBEROFPIECES=$PIECES.Count 
	$FILENAME=$PIECES[$NumberOfPieces-1] 
	$DIRECTORYPATH=$FullPathName.Trim($FILENAME) 
	return $FILENAME

}

$ENVIRONMENT = $args[0]
$BUILD = $args[1]
$SOLUTION = $args[2]
$WORK_DIR_DEFAULT = $args[3]
$scriptName = $myInvocation.MyCommand.Name
$localPropertiesPath = 'propertiesForLocalTasks\'
$localPropertiesFilter = $localPropertiesPath + "$ENVIRONMENT*"
$localEnvironmentPath = 'propertiesForLocalEnvironment\'

Write-Host "[$scriptName]   ENVIRONMENT            : $ENVIRONMENT" 
Write-Host "[$scriptName]   BUILD                  : $BUILD" 
Write-Host "[$scriptName]   SOLUTION               : $SOLUTION" 
Write-Host "[$scriptName]   WORK_DIR_DEFAULT       : $WORK_DIR_DEFAULT" 

# change to working directory
cd $WORK_DIR_DEFAULT

# Pre and Post traget processing tasks
$propertiesFile = "$localEnvironmentPath\$ENVIRONMENT"
if ( Test-Path $propertiesFile ) {
	try {
		$localEnvPreDeployTask=$(& .\getProperty.ps1 $propertiesFile "localEnvPreDeployTask")
		if(!$?){ taskWarning }
	} catch { exitWithCode "GET_ENVIRONMENT_PRE_TASK" 101 }
	Write-Host "[$scriptName]   localEnvPreDeployTask  : $localEnvPreDeployTask" 
	
	try {
		$localEnvPostDeployTask=$(& .\getProperty.ps1 $propertiesFile "localEnvPostDeployTask")
		if(!$?){ taskWarning }
	} catch { exitWithCode "GET_ENVIRONMENT_POST_TASK" 102 }
	Write-Host "[$scriptName]   localEnvPostDeployTask : $localEnvPostDeployTask" 

} else {

	Write-Host "[$scriptName]   localEnvironmentPath   : (not defined)" 

}

$propertiesFile = "CDAF.properties"
$propName = "productVersion"
try {
	$cdafVersion=$(& .\getProperty.ps1 $propertiesFile $propName)
	if(!$?){ taskWarning }
} catch { exitWithCode "GET_CDAF_VERSION" 103 }
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
	    if(!$?){ exitWithCode "EXECUTE_TRAP" 200 }
    } catch { exitWithCode "EXECUTE_EXCEPTION" 201}
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
		} catch { exitWithCode $propFilename 202}
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
	    if(!$?){ exitWithCode "EXECUTE_TRAP" 210}
    } catch { exitWithCode "EXECUTE_EXCEPTION" 211}
}

# Return to root
cd ..
