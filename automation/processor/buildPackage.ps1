# Entry Point for Build Process, child scripts inherit the functions of parent scripts, so these definitions are global for the CI process
# Primary powershell, returns exitcode to DOS
function exitWithCode ($message, $exitCode) {
    write-host "[$scriptName] $message" -ForegroundColor Red
    write-host "[$scriptName]   Returning errorlevel $exitCode to DOS" -ForegroundColor Magenta
    $host.SetShouldExit($exitCode)
    exit $exitCode
}

function passExitCode ($message, $exitCode) {
    write-host "[$scriptName] $message" -ForegroundColor Red
    write-host "[$scriptName]   Exiting with `$LASTEXITCODE $exitCode" -ForegroundColor Magenta
    exit $exitCode
}

function exceptionExit ($exception) {
    write-host "[$scriptName]   Exception details follow ..." -ForegroundColor Red
    echo $exception.Exception|format-list -force
    write-host "[$scriptName] Returning errorlevel (20) to DOS" -ForegroundColor Magenta
    $host.SetShouldExit(20)
    exit
}

# Not used in this script because called from DOS, but defined here for all child scripts
function taskFailure ($taskName) {
    write-host
    write-host "[$scriptName] Failure occured! Code returned ... $taskName" -ForegroundColor Red
    $host.SetShouldExit(30)
    exit
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
	} catch { exceptionExit $_ }
	
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
	exitWithCode "Build Number not supplied!" 21
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
		exitWithCode "SOLUTION_NOT_FOUND Solution not supplied and unable to derive from $solutionRoot\CDAF.solution" 22
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

& .\$AUTOMATIONROOT\buildandpackage\buildProjects.ps1 $SOLUTION $BUILDNUMBER $REVISION $AUTOMATIONROOT $solutionRoot $ACTION
if($LASTEXITCODE -ne 0){
	exitWithCode "BUILD_NON_ZERO_EXIT .\$AUTOMATIONROOT\buildandpackage\buildProjects.ps1 $SOLUTION $BUILDNUMBER $REVISION $AUTOMATIONROOT $solutionRoot $ACTION" $LASTEXITCODE
}
if(!$?){ taskWarning "buildProjects.ps1" }

& .\$AUTOMATIONROOT\buildandpackage\package.ps1 $SOLUTION $BUILDNUMBER $REVISION $AUTOMATIONROOT $solutionRoot $LOCAL_WORK_DIR $REMOTE_WORK_DIR $ACTION
if($LASTEXITCODE -ne 0){
	exitWithCode "PACKAGE_NON_ZERO_EXIT .\$AUTOMATIONROOT\buildandpackage\package.ps1 $SOLUTION $BUILDNUMBER $REVISION $AUTOMATIONROOT $solutionRoot $LOCAL_WORK_DIR $REMOTE_WORK_DIR $ACTION" $LASTEXITCODE
}
if(!$?){ taskWarning "package.ps1" }
