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
$localProperties = "propertiesForLocalTasks\$ENVIRONMENT*"

Write-Host "[$scriptName]   ENVIRONMENT      : $ENVIRONMENT" 
Write-Host "[$scriptName]   BUILD            : $BUILD" 
Write-Host "[$scriptName]   SOLUTION         : $SOLUTION" 
Write-Host "[$scriptName]   WORK_DIR_DEFAULT : $WORK_DIR_DEFAULT" 
Write-Host "[$scriptName]   Hostname         : $(hostname)" 
Write-Host "[$scriptName]   Whoami           : $(whoami)" 

# change to working directory
cd $WORK_DIR_DEFAULT

$propertiesFile = "CDAF.properties"
$propName = "productVersion"
try {
	$cdafVersion=$(& .\getProperty.ps1 $propertiesFile $propName)
	if(!$?){ taskWarning }
} catch { exitWithCode "GET_CDAF_VERSION" }
Write-Host "[$scriptName]   CDAF Version     : $cdafVersion"
Write-Host "[$scriptName]   pwd              : $(pwd)"
 
$exitStatus = 0

# Perform Local Tasks for each environment definition file

if (-not(Test-Path $localProperties)) {

	Write-Host "[$scriptName] local properties not found ($localProperties) assuming this is new implementation, no action attempted" -ForegroundColor Yellow

} else {


	Write-Host
	Write-Host "[$scriptName] Preparing to process targets :"
	Write-Host
	foreach ($propFile in (Get-ChildItem -Path $localProperties)) {
		$propFilename = getFilename($propFile.ToString())
		Write-Host "[$scriptName]   $propFilename"
	}

	foreach ($propFile in (Get-ChildItem -Path $localProperties)) {

		$propFilename = getFilename($propFile.ToString())

		Write-Host
		write-host "[$scriptName]   --- Process Target $propFilename --- " -ForegroundColor Green
		try {
			& .\localTasksTarget.ps1 $ENVIRONMENT $SOLUTION $BUILD $propFilename
			if(!$?){ taskWarning }
		} catch { exitWithCode $propFilename }
		Write-Host
		write-host "[$scriptName]   --- Completed Target $propFilename --- " -ForegroundColor Green
	}
}

# Return to root
cd ..
