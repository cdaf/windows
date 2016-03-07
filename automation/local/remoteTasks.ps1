function exitWithCode($taskName) {
    write-host
    write-host "[$scriptName] Caught an exception excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    write-host
    write-host "     Returning errorlevel (-1) to DOS" -ForegroundColor Magenta
    write-host
    $host.SetShouldExit(-1)
    exit
}

function taskError ($taskName) {
    write-host "[$scriptName] Error occured when excuting $taskName :" -ForegroundColor Red
	write-host
    throw "$taskName HALT"
}

function taskWarning { 
    write-host "[$scriptName] Warning, $taskName encountered an error that was allowed to proceed." -ForegroundColor Yellow
}

function getProp ($propName) {

	try {
		$propValue=$(& .\$WORK_DIR_DEFAULT\getProperty.ps1 $propertiesFile $propName)
		if(!$?){ taskWarning }
	} catch { exitWithCode 'getProp' }
	
    return $propValue
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
$remoteProperties = "propertiesForRemoteTasks\$ENVIRONMENT*"

Write-Host "[$scriptName]   ENVIRONMENT      : $ENVIRONMENT" 
Write-Host "[$scriptName]   BUILD            : $BUILD" 
Write-Host "[$scriptName]   SOLUTION         : $SOLUTION" 
Write-Host "[$scriptName]   WORK_DIR_DEFAULT : $WORK_DIR_DEFAULT" 
Write-Host "[$scriptName]   Hostname         : $(hostname)" 
Write-Host "[$scriptName]   Whoami           : $(whoami)" 

$propertiesFile = "CDAF.properties"
$propName = "productVersion"
try {
	$cdafVersion=$(& .\$WORK_DIR_DEFAULT\getProperty.ps1 .\$WORK_DIR_DEFAULT\$propertiesFile $propName)
	if(!$?){ taskWarning }
} catch { exitWithCode 'GET_CDAF_VERSION' }
Write-Host "[$scriptName]   CDAF Version     : $cdafVersion"
Write-Host "[$scriptName]   pwd              : $(pwd)"
 
$exitStatus = 0

# Perform Remote Tasks for each environment defintion file

if (-not(Test-Path $WORK_DIR_DEFAULT\$remoteProperties)) {

	Write-Host "[$scriptName] Remote properties not found ($WORK_DIR_DEFAULT\$remoteProperties) assuming this is new implementation, no action attempted" -ForegroundColor Yellow

} else {

	Write-Host
	Write-Host "[$scriptName] Preparing to process deploy targets :"
	Write-Host
	foreach ($propFile in (Get-ChildItem -Path $WORK_DIR_DEFAULT\$remoteProperties)) {
		$propFilename = getFilename($propFile.ToString())
		Write-Host "[$scriptName]   $propFilename"
	}

	foreach ($propFile in (Get-ChildItem -Path $WORK_DIR_DEFAULT\$remoteProperties)) {
		$propFilename = getFilename($propFile.ToString())

		Write-Host
		write-host "[$scriptName]   --- Process Target $propFilename --- " -ForegroundColor Green
		Write-Host
		try {
			& .\$WORK_DIR_DEFAULT\remoteTasksTarget.ps1 $ENVIRONMENT $SOLUTION $BUILD $propFilename $WORK_DIR_DEFAULT
			if(!$?){ taskWarning }
		} catch { exitWithCode "$propFilename" }
		Write-Host
		write-host "[$scriptName]   --- Completed Target $propFilename --- " -ForegroundColor Green
		Write-Host
	}
}
