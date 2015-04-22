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
$SOLUTION = $args[1]
$BUILD = $args[2]
$WORK_DIR_DEFAULT = $args[3]
$scriptName = $myInvocation.MyCommand.Name 
$localProperties = "propertiesForLocalTasks\$ENVIRONMENT*"

Write-Host "[$scriptName] Executing on $(hostname) as $(whoami) in $(pwd)" 
$exitStatus = 0

# change to working directory
cd $WORK_DIR_DEFAULT

# Perform Local Tasks for each environment defintion file

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
		Write-Host
		try {
			& .\localTasksTarget.ps1 $ENVIRONMENT $BUILD $SOLUTION $propFilename
			if(!$?){ taskWarning }
		} catch { exitWithCode $propFilename }
		Write-Host
		write-host "[$scriptName]   --- Completed Target $propFilename --- " -ForegroundColor Green
		Write-Host

	}
}

# Return to root
cd ..
