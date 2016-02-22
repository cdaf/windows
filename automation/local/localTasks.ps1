function exceptionExit ($taskName, $dosExit) {
    write-host
    write-host "[$scriptName] Caught an exception excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    write-host
    write-host "     Returning errorlevel ($dosExit) to DOS" -ForegroundColor Magenta
    write-host
    $host.SetShouldExit($dosExit)
    exit
}

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

Write-Host "[$scriptName]   ENVIRONMENT      : $ENVIRONMENT" 
Write-Host "[$scriptName]   BUILD            : $BUILD" 
Write-Host "[$scriptName]   SOLUTION         : $SOLUTION" 
Write-Host "[$scriptName]   WORK_DIR_DEFAULT : $WORK_DIR_DEFAULT" 

# change to working directory
cd $WORK_DIR_DEFAULT

$propertiesFile = "CDAF.properties"
$propName = "productVersion"
try {
	$cdafVersion=$(& .\getProperty.ps1 $propertiesFile $propName)
	if(!$?){ taskWarning }
} catch { exceptionExit "GET_CDAF_VERSION" 101 }
Write-Host "[$scriptName]   CDAF Version     : $cdafVersion"

# list system info
Write-Host "[$scriptName]   pwd              : $(pwd)"
Write-Host "[$scriptName]   Hostname         : $(hostname)" 
Write-Host "[$scriptName]   Whoami           : $(whoami)" 

$exitStatus = 0

# If there is a properties file that matches the environment name, check this file for external CM configuration
$propertiesFile = "$localPropertiesPath\$ENVIRONMENT"
if ( Test-Path $propertiesFile ) {
	$propName = "externalCM"
	try {
		$externalCM=$(& .\getProperty.ps1 $propertiesFile $propName)
		if(!$?){ taskWarning }
	} catch { exceptionExit "READ_MANIFEST" 100 }
	Write-Host "[$scriptName]   externalCM       : $externalCM"
	
	# If an external configuration management repository is set, then load properties from a zip file..
	if ($externalCM) {
		$propertiesFile = "$localPropertiesPath\$ENVIRONMENT"
		# Write-Host "[DEBUG] Directory listing `$localPropertiesPath ($localPropertiesPath): $(dir $localPropertiesPath)" -ForegroundColor Blue
		try {
			$externalRepoUser=$(& .\getProperty.ps1 $propertiesFile 'externalRepoUser')
			$externalRepoPass=$(& .\getProperty.ps1 $propertiesFile 'externalRepoPass')
			$PORTABLE_CERTIFICATE_THUMBPRINT=$(& .\getProperty.ps1 $propertiesFile 'PORTABLE_CERTIFICATE_THUMBPRINT')
			$externalCM=$(& .\getProperty.ps1 $propertiesFile 'externalCM')
			if(!$?){ taskWarning }
		} catch { exceptionExit "GET_EXTERNAL_REPO" 102}
	
		$password = $(& .\decryptKey.ps1 $externalRepoPass $PORTABLE_CERTIFICATE_THUMBPRINT)
		# Write-Host "[DEBUG] `$password = $password" -ForegroundColor Blue
		if ($password) {
			& .\getEnvRepo.ps1 $externalRepoUser $password $externalCM $ENVIRONMENT
	        $exitcode = $LASTEXITCODE
	        if ( $exitcode -gt 0 ) {exitWithCode "getEnvRepo" $exitcode }
		} else {
			exceptionExit "GET_PASSWORD_FAILED" 203
		}
		# Write-Host "[DEBUG] Directory listing `$localPropertiesPath ($localPropertiesPath): $(dir $localPropertiesPath)" -ForegroundColor Blue
		Write-Host
		Write-Host "[$scriptName] Delete the environment properies file to ensure only target files are processed."
		Write-Host "[$scriptName] Remove-Item $localPropertiesPath\$ENVIRONMENT"
		Remove-Item $localPropertiesPath\$ENVIRONMENT
		# Write-Host "[DEBUG] Directory listing `$localPropertiesPath ($localPropertiesPath): $(dir $localPropertiesPath)" -ForegroundColor Blue
	}
}

# Perform Local Tasks for each environment definition file

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
		} catch { exceptionExit $propFilename 104}
		Write-Host
		write-host "[$scriptName]   --- Completed Target $propFilename --- " -ForegroundColor Green
	}
}

# Return to root
cd ..
