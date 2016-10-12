# Entry Point for Build Process, child scripts inherit the functions of parent scripts, so these definitions are global for the CI process

function exitWithCode ($exception) {
    write-host "[$scriptName]   Exception details follow ..." -ForegroundColor Red
    echo $exception.Exception|format-list -force
    write-host "[$scriptName] Returning errorlevel (-1) to DOS" -ForegroundColor Magenta
    $host.SetShouldExit(-1)
    exit
}

# Not used in this script because called from DOS, but defined here for all child scripts
function taskFailure ($taskName) {
    write-host
    write-host "[$scriptName] Failure occured! Code returned ... $taskName" -ForegroundColor Red
    throw "$scriptName $taskName"
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
	write-host
    throw "$taskName HALT"
}

function getProp ($propName) {

	try {
		$propValue=$(& $WORK_DIR_DEFAULT\getProperty.ps1 $propertiesFile $propName)
		if(!$?){ taskWarning }
	} catch { taskFailure 'getProp' }
	
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

$ENVIRONMENT = $args[0]
if ( $ENVIRONMENT ) {
	Write-Host "[$scriptName]   ENVIRONMENT      : $ENVIRONMENT"
} else { 
	Write-Host "[$scriptName] Environment not supplied!"
	exitWithCode "ENVIRONMENT_NOT_SUPPLIED" 
}

$RELEASE = $args[1]
if ( $RELEASE ) {
	Write-Host "[$scriptName]   RELEASE          : $RELEASE"
} else {
	$RELEASE = 'Release'
	Write-Host "[$scriptName]   RELEASE          : $RELEASE (default)"
}

$OPT_ARG = $args[2]
Write-Host "[$scriptName]   OPT_ARG          : $OPT_ARG"

$WORK_DIR_DEFAULT = $args[3]
if ( $WORK_DIR_DEFAULT ) {
	Write-Host "[$scriptName]   WORK_DIR_DEFAULT : $WORK_DIR_DEFAULT"
} else {
	$WORK_DIR_DEFAULT = 'TasksLocal'
	Write-Host "[$scriptName]   WORK_DIR_DEFAULT : $WORK_DIR_DEFAULT (default)"
}

$SOLUTION = $args[4]
if ($SOLUTION) {
	Write-Host "[$scriptName]   SOLUTION         : $SOLUTION"
} else {
	$propertiesFile = "$WORK_DIR_DEFAULT\manifest.txt"
	$SOLUTION = getProp 'SOLUTION'
	if ($SOLUTION) {
		Write-Host "[$scriptName]   SOLUTION         : $SOLUTION (from $WORK_DIR_DEFAULT\manifest.txt)"
	} else {
		Write-Host "[$scriptName] Solution not supplied and unable to derive from manifest.txt"
		exitWithCode "SOLUTION_NOT_SUPPLIED" 
	}
}

$BUILDNUMBER = $args[5]
if ($BUILDNUMBER) {
	Write-Host "[$scriptName]   BUILDNUMBER      : $BUILDNUMBER"
} else {
	$propertiesFile = "$WORK_DIR_DEFAULT\manifest.txt"
	$BUILDNUMBER = getProp 'BUILDNUMBER'
	if ($BUILDNUMBER) {
		Write-Host "[$scriptName]   BUILDNUMBER      : $BUILDNUMBER (from $WORK_DIR_DEFAULT\manifest.txt)"
	} else {
		Write-Host "[$scriptName] Build number not supplied and unable to derive from manifest.txt"
		exitWithCode "BUILDNUMBER_NOT_SUPPLIED" 
	}
}

# Runtime information
Write-Host "[$scriptName]   pwd              : $(pwd)"
Write-Host "[$scriptName]   hostname         : $(hostname)" 
Write-Host "[$scriptName]   whoami           : $(whoami)"

$propertiesFile = "$WORK_DIR_DEFAULT\CDAF.properties"
$cdafVersion = getProp 'productVersion'
Write-Host "[$scriptName]   CDAF Version     : $cdafVersion"

try {
	& .\$WORK_DIR_DEFAULT\remoteTasks.ps1 $ENVIRONMENT $BUILDNUMBER $SOLUTION $WORK_DIR_DEFAULT $OPT_ARG
	if(!$?){ taskWarning }
} catch {
	Write-Host
	Write-Host "[$scriptName] Exception thrown from & .\$WORK_DIR_DEFAULT\remoteTasks.ps1 $ENVIRONMENT $BUILDNUMBER $SOLUTION $WORK_DIR_DEFAULT $OPT_ARG"
	exitWithCode $_ 
}

try {
	& .\$WORK_DIR_DEFAULT\localTasks.ps1 $ENVIRONMENT $BUILDNUMBER $SOLUTION $WORK_DIR_DEFAULT $OPT_ARG
	if(!$?){ taskWarning }
} catch {
	Write-Host
	Write-Host "[$scriptName] Exception thrown from & .\$WORK_DIR_DEFAULT\localTasks.ps1 $ENVIRONMENT $BUILDNUMBER $SOLUTION $WORK_DIR_DEFAULT $OPT_ARG"
	exitWithCode $_ 
}
