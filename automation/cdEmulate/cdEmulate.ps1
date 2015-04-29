param(
    [Parameter(Mandatory = $true)]
    $AUTOMATIONROOT,

    [Parameter(Mandatory = $false)]
    $ACTION
)

function exitWithCode ($taskName) {
    write-host
    write-host "[$scriptName] $taskName failed!" -ForegroundColor Red
    write-host
    write-host "     Returning errorlevel (-1) to DOS" -ForegroundColor Magenta
    write-host
    $host.SetShouldExit(-1)
    exit
}

function itemRemove ($itemPath) { 
	if ( Test-Path $itemPath ) {
		write-host "[$scriptName] Delete $itemPath"
		Remove-Item $itemPath -Recurse 
		if(!$?){ exitWithCode("Remove-Item $itemPath") }
	}
}

$exitStatus          = 0
$scriptName          = $MyInvocation.MyCommand.Name

$automationHelper    = "$AUTOMATIONROOT\remote"
$environmentBuild    = "BUILD"
$environmentDelivery = "DEV"
$workDirLocal        = "TasksLocal"
$workDirRemote       = "TasksRemote"

# This first line reflects the batch override launcher logging and is included to aid in text alignment
#            echo [%~nx0]   ACTION              : %ACTION%
Write-Host "[$scriptName]   environmentBuild    : $environmentBuild"
Write-Host "[$scriptName]   environmentDelivery : $environmentDelivery"

# Check for user defined solution folder, i.e. outside of automation root, if found override solution root
Write-Host "[$scriptName]   solutionRoot        : " -NoNewline
foreach ($item in (Get-ChildItem -Path ".")) {
	if ($item.Attributes -eq "Directory") {
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

# Check for customised CI process
Write-Host "[$scriptName]   ciProcess           : " -NoNewline
if (Test-Path "$solutionRoot\cdEmulate-ci.bat") {
	$ciProcess="$solutionRoot\cdEmulate\cdEmulate-ci.bat"
	write-host "$ciProcess (override)"
} else {
	$ciProcess="$AUTOMATIONROOT\cdEmulate\cdEmulate-ci.bat"
	write-host "$ciProcess (default)"
}

# Check for customised Delivery process
Write-Host "[$scriptName]   cdProcess           : " -NoNewline
if (Test-Path "$solutionRoot\cdEmulate-deliver.bat") {
	$cdProcess="$solutionRoot\cdEmulate\cdEmulate-deliver.bat"
	write-host "$cdProcess (override)"
} else {
	$cdProcess="$AUTOMATIONROOT\cdEmulate\cdEmulate-deliver.bat"
	write-host "$cdProcess (default)"
}

if (Test-Path "$solutionRoot\CDAF.solution") {
	write-host
	write-host "[$scriptName] Load Solution Properties $solutionRoot\CDAF.solution"
	& .\$automationHelper\Transform.ps1 "$solutionRoot\CDAF.solution" | ForEach-Object { invoke-expression $_ }
}

if (! $solution) {
	$solution = $(Get-Item -Path .).Name
	write-host
	write-host "[$scriptName] Solution name not defined in $solutionRoot\CDAF.solution, defaulting to current path, $solution"
}

# Use timestamp to ensure unique build number and emulate the revision ID (source control)
$buildNumber=get-date -f yyyyMMddHHmmss
$revision=get-date -f HHmmss

# Process Build and Package
& $ciProcess $solution $environmentBuild $buildNumber $revision $AUTOMATIONROOT $workDirLocal $workDirRemote $ACTION
if(!$?){ exitWithCode $ciProcess }

# Do not process Remote and Local Tasks if the action is just clean
if ( $ACTION -eq "clean" ) {
	write-host
	write-host "[$scriptName] No Delivery Action attempted when clean only action"
} else {
	& $cdProcess $solution $environmentDelivery $buildNumber $revision $AUTOMATIONROOT $workDirLocal $workDirRemote $ACTION
	if(!$?){ exitWithCode $ciProcess }
}

write-host
write-host "[$scriptName] ------------------"
write-host "[$scriptName] Emulation Complete"
write-host "[$scriptName] ------------------"
write-host
