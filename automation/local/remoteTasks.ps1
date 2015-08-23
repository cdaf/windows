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

function taskException ($taskName, $invokeException) {
    write-host "[$scriptName] Caught an exception excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($invokeException.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($invokeException.Exception.Message)" -ForegroundColor Red
	write-host
    throw "$taskName HALT"
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
	} catch { taskException("getProp") }
	
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
$SOLUTION = $args[1]
$BUILD = $args[2]
$WORK_DIR_DEFAULT = $args[3]
$scriptName = $myInvocation.MyCommand.Name 
$remoteProperties = "propertiesForRemoteTasks\$ENVIRONMENT*"

Write-Host "[$scriptName] Executing on $(hostname) as $(whoami) in $(pwd)" 
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
			& .\$WORK_DIR_DEFAULT\remoteTasksTarget.ps1 $ENVIRONMENT $BUILD $SOLUTION $propFilename $WORK_DIR_DEFAULT
			if(!$?){ taskWarning }
		} catch { exitWithCode($propFilename) }
		Write-Host
		write-host "[$scriptName]   --- Completed Target $propFilename --- " -ForegroundColor Green
		Write-Host
	}
}
