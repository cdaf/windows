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
		if(!$?){ taskFailure "Remove-Item $itemPath" }
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

function getProp ($propName) {
	try {
		$propValue=$(& .\$AUTOMATIONROOT\remote\getProperty.ps1 $propertiesFile $propName)
		if(!$?){ taskWarning }
	} catch { taskFailure "getProp_$propName" }
	
    return $propValue
}

$exitStatus = 0
$scriptName = $MyInvocation.MyCommand.Name

# Load automation root out of sequence as needed for solution root derivation
$AUTOMATIONROOT = $args[4]
if (!($AUTOMATIONROOT)) {
	$AUTOMATIONROOT = 'automation'
}
# Check for user defined solution folder, i.e. outside of automation root, if found override solution root
Write-Host "[$scriptName]   solutionRoot    : " -NoNewline
foreach ($item in (Get-ChildItem -Path ".")) {
	if (Test-Path $item -PathType "Container") {
		if (Test-Path "$item\CDAF.solution") {
			$solutionRoot=$item
		}
	}
}
if ($solutionRoot) {
	write-host "$solutionRoot (override $solutionRoot\CDAF.solution found)"
} else {
	$solutionRoot="$AUTOMATIONROOT\solution"
	write-host "$solutionRoot (default, project directory containing CDAF.solution not found)"
}

$BUILDNUMBER = $args[0]
if ( $BUILDNUMBER ) {
	Write-Host "[$scriptName]   BUILDNUMBER     : $BUILDNUMBER"
} else { 
	Write-Host "[$scriptName] Build Number not supplied!"
	exitWithCode "BUILDNUMBER_NOT_SUPPLIED" 
}

$REVISION = $args[1]
if ( $REVISION ) {
	Write-Host "[$scriptName]   REVISION        : $REVISION"
} else {
	$REVISION = 'Revision'
	Write-Host "[$scriptName]   REVISION        : $REVISION (default)"
}

$ACTION = $args[2]
Write-Host "[$scriptName]   ACTION          : $ACTION"

$SOLUTION = $args[3]
if ($SOLUTION) {
	Write-Host "[$scriptName]   SOLUTION        : $SOLUTION"
} else {
	$propertiesFile = "$solutionRoot\CDAF.solution"
	$SOLUTION = getProp 'solutionName'
	if ($SOLUTION) {
		Write-Host "[$scriptName]   SOLUTION        : $SOLUTION (from `$solutionRoot\CDAF.solution)"
	} else {
		Write-Host "[$scriptName] Solution not supplied and unable to derive from $solutionRoot\CDAF.solution"
		exitWithCode "SOLUTION_NOT_SUPPLIED" 
	}
}

# Arguments out of order, as automation root processed first
$LOCAL_WORK_DIR = $args[5]
if ( $LOCAL_WORK_DIR ) {
	Write-Host "[$scriptName]   LOCAL_WORK_DIR  : $LOCAL_WORK_DIR"
} else {
	$LOCAL_WORK_DIR = 'TasksLocal'
	Write-Host "[$scriptName]   LOCAL_WORK_DIR  : $LOCAL_WORK_DIR (default)"
}

$REMOTE_WORK_DIR = $args[6]
if ( $REMOTE_WORK_DIR ) {
	Write-Host "[$scriptName]   REMOTE_WORK_DIR : $REMOTE_WORK_DIR"
} else {
	$REMOTE_WORK_DIR = 'TasksRemote'
	Write-Host "[$scriptName]   REMOTE_WORK_DIR : $REMOTE_WORK_DIR (default)"
}

Write-Host "[$scriptName]   AUTOMATIONROOT  : $AUTOMATIONROOT" 

# Runtime information
Write-Host "[$scriptName]   pwd             : $(pwd)"
Write-Host "[$scriptName]   hostname        : $(hostname)" 
Write-Host "[$scriptName]   whoami          : $(whoami)"

$propertiesFile = "$AUTOMATIONROOT\CDAF.windows"
$cdafVersion = getProp 'productVersion'
Write-Host "[$scriptName]   CDAF Version    : $cdafVersion"

try {
	& .\$AUTOMATIONROOT\buildandpackage\buildProjects.ps1 $SOLUTION $BUILDNUMBER $REVISION $AUTOMATIONROOT $solutionRoot $ACTION
	if(!$?){ taskWarning }
} catch {
	Write-Host
	Write-Host "[$scriptName] Exception thrown from & .\$AUTOMATIONROOT\buildandpackage\buildProjects.ps1 $SOLUTION $BUILDNUMBER $REVISION $AUTOMATIONROOT $solutionRoot $ACTION"
	exitWithCode $_ 
}

try {
	& .\$AUTOMATIONROOT\buildandpackage\package.ps1 $SOLUTION $BUILDNUMBER $REVISION $AUTOMATIONROOT $solutionRoot $LOCAL_WORK_DIR $REMOTE_WORK_DIR $ACTION
	if(!$?){ taskWarning }
} catch {
	Write-Host
	Write-Host "[$scriptName] Exception thrown from & .\$AUTOMATIONROOT\buildandpackage\package.ps1 $SOLUTION $BUILDNUMBER $REVISION $AUTOMATIONROOT $solutionRoot $LOCAL_WORK_DIR $REMOTE_WORK_DIR $ACTION"
	exitWithCode $_ 
}
