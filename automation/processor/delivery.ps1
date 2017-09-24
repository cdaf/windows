Param (
	[string]$ENVIRONMENT,
	[string]$RELEASE,
	[string]$OPT_ARG,
	[string]$WORK_DIR_DEFAULT,
	[string]$SOLUTION,
	[string]$BUILDNUMBER
)

# Entry Point for Build Process, child scripts inherit the functions of parent scripts, so these definitions are global for the CD process
# Primary powershell, returns exitcode to DOS
function exceptionExit ($exception) {
    write-host "`n[$scriptName] Exception details follow ..." -ForegroundColor Magenta
    echo $exception.Exception|format-list -force
	write-host "[$scriptName]   `$host.SetShouldExit(50)" -ForegroundColor Red
	$host.SetShouldExit(50); exit
}

function passExitCode ($message, $exitCode) {
    write-host "[$scriptName] $message" -ForegroundColor Red
    write-host "[$scriptName]   Exiting with `$LASTEXITCODE $exitCode" -ForegroundColor Magenta
    exit $exitCode
}

function taskFailure ($taskName) {
    write-host "`n[$scriptName] $taskName" -ForegroundColor Red
	write-host "[$scriptName]   `$host.SetShouldExit(60)" -ForegroundColor Red
	$host.SetShouldExit(60); exit
}

function taskWarning { 
    write-host "[$scriptName] Warning, $taskName encountered an error that was allowed to proceed." -ForegroundColor Yellow
}

function itemRemove ($itemPath) { 
	if ( Test-Path $itemPath ) {
		write-host "[$scriptName] Delete $itemPath"
		Remove-Item $itemPath -Recurse 
		if(!$?){ taskFailure("Remove-Item $itemPath") }
	}
}

function removeTempFiles { 
    if (Test-Path projectsToBuild.txt) {
        Remove-Item projectsToBuild.txt -recurse
    }

    if (Test-Path projectDirectories.txt) {
        Remove-Item projectDirectories.txt -recurse
    }
}

function pathTest ($pathToTest) { 
	if ( Test-Path $pathToTest ) {
		Write-Host "found ($pathToTest)"
	} else {
		Write-Host "none ($pathToTest)"
	}
}

function taskError ($taskName) {
    write-host "[$scriptName] Error occured when excuting $taskName :" -ForegroundColor Red
    $host.SetShouldExit(70)
    exit
}

function getProp ($propName) {

	try {
		$propValue=$(& $WORK_DIR_DEFAULT\getProperty.ps1 $propertiesFile $propName)
		if(!$?){ taskWarning }
	} catch { exceptionExit $_ }
	
    return $propValue
}

function getFilename ($FullPathName) {

	$PIECES=$FullPathName.split(“\”) 
	$NUMBEROFPIECES=$PIECES.Count 
	$FILENAME=$PIECES[$NumberOfPieces-1] 
	$DIRECTORYPATH=$FullPathName.Trim($FILENAME) 
	return $FILENAME

}

$exitStatus = 0
$scriptName = $MyInvocation.MyCommand.Name

if ( $ENVIRONMENT ) {
	Write-Host "[$scriptName]   ENVIRONMENT      : $ENVIRONMENT"
} else { 
	Write-Host "[$scriptName] ENVIRONMENT_NOT_SUPPLIED Environment not supplied!" -ForegroundColor Red
    write-host "[$scriptName]   `$host.SetShouldExit(51)" -ForegroundColor Red
    $host.SetShouldExit(51); exit
}

if ( $RELEASE ) {
	Write-Host "[$scriptName]   RELEASE          : $RELEASE"
} else {
	$RELEASE = 'Release'
	Write-Host "[$scriptName]   RELEASE          : $RELEASE (default)"
}

Write-Host "[$scriptName]   OPT_ARG          : $OPT_ARG"

if ( $WORK_DIR_DEFAULT ) {
	Write-Host "[$scriptName]   WORK_DIR_DEFAULT : $WORK_DIR_DEFAULT"
} else {
	$WORK_DIR_DEFAULT = 'TasksLocal'
	Write-Host "[$scriptName]   WORK_DIR_DEFAULT : $WORK_DIR_DEFAULT (default)"
}

if ($SOLUTION) {
	Write-Host "[$scriptName]   SOLUTION         : $SOLUTION"
} else {
	$propertiesFile = "$WORK_DIR_DEFAULT\manifest.txt"
	$SOLUTION = getProp 'SOLUTION'
	if ($SOLUTION) {
		Write-Host "[$scriptName]   SOLUTION         : $SOLUTION (from $WORK_DIR_DEFAULT\manifest.txt)"
	} else {
		Write-Host "[$scriptName] DELIVERY_SOLUTION_NOT_FOUND Solution not supplied and unable to derive from manifest.txt"
	    write-host "[$scriptName]   `$host.SetShouldExit(54)" -ForegroundColor Red
	    $host.SetShouldExit(54); exit
	}
}

if ($BUILDNUMBER) {
	Write-Host "[$scriptName]   BUILDNUMBER      : $BUILDNUMBER"
} else {
	$propertiesFile = "$WORK_DIR_DEFAULT\manifest.txt"
	$BUILDNUMBER = getProp 'BUILDNUMBER'
	if ($BUILDNUMBER) {
		Write-Host "[$scriptName]   BUILDNUMBER      : $BUILDNUMBER (from $WORK_DIR_DEFAULT\manifest.txt)"
	} else {
		Write-Host "[$scriptName] DELIVERY_BUILD_NUMBER_NOT_FOUND Build number not supplied and unable to derive from manifest.txt"
	    write-host "[$scriptName]   `$host.SetShouldExit(55)" -ForegroundColor Red
	    $host.SetShouldExit(55); exit
	}
}

# Runtime information
Write-Host "[$scriptName]   pwd              : $(pwd)"
Write-Host "[$scriptName]   hostname         : $(hostname)" 
Write-Host "[$scriptName]   whoami           : $(whoami)"

$propertiesFile = "$WORK_DIR_DEFAULT\CDAF.properties"
$cdafVersion = getProp 'productVersion'
Write-Host "[$scriptName]   CDAF Version     : $cdafVersion"

& .\$WORK_DIR_DEFAULT\remoteTasks.ps1 $ENVIRONMENT $BUILDNUMBER $SOLUTION $WORK_DIR_DEFAULT $OPT_ARG
if( $LASTEXITCODE -ne 0 ){
    write-host "[$scriptName] REMOTE_NON_ZERO_EXIT & .\$WORK_DIR_DEFAULT\remoteTasks.ps1 $ENVIRONMENT $BUILDNUMBER $SOLUTION $WORK_DIR_DEFAULT $OPT_ARG" -ForegroundColor Magenta
	write-host "[$scriptName]   `$host.SetShouldExit($LASTEXITCODE)" -ForegroundColor Red
	$host.SetShouldExit($LASTEXITCODE); exit
}
if(!$?){ taskWarning }

& .\$WORK_DIR_DEFAULT\localTasks.ps1 $ENVIRONMENT $BUILDNUMBER $SOLUTION $WORK_DIR_DEFAULT $OPT_ARG
if( $LASTEXITCODE -ne 0 ){
    write-host "[$scriptName] LOCAL_NON_ZERO_EXIT & .\$WORK_DIR_DEFAULT\localTasks.ps1 $ENVIRONMENT $BUILDNUMBER $SOLUTION $WORK_DIR_DEFAULT $OPT_ARG" -ForegroundColor Magenta
	write-host "[$scriptName]   `$host.SetShouldExit($LASTEXITCODE)" -ForegroundColor Red
	$host.SetShouldExit($LASTEXITCODE); exit
}
if(!$?){ taskWarning }
