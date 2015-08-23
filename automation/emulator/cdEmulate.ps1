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

$scriptName          = $MyInvocation.MyCommand.Name

# Framework structure
$AUTOMATIONROOT      = "automation"
$automationHelper    = "$AUTOMATIONROOT\remote"
$workDirLocal        = "TasksLocal"
$workDirRemote       = "TasksRemote"

# Build and Delivery Properties Lookup values
$environmentBuild    = "BUILD"
$environmentDelivery = "DEV"
Write-Host "[$scriptName]   environmentBuild    : $environmentBuild"
Write-Host "[$scriptName]   environmentDelivery : $environmentDelivery"

# Use timestamp to ensure unique build number and emulate the revision ID (source control)
# In Bamboo parameter is  ${bamboo.buildNumber}
$buildNumber=get-date -f MMddHHmmss
$revision=get-date -f HHmmss
Write-Host "[$scriptName]   buildNumber         : $buildNumber"
Write-Host "[$scriptName]   revision            : $revision"

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
	$ciProcess="$solutionRoot\cdEmulate-ci.bat"
	write-host "$ciProcess (override)"
} else {
	$ciProcess="$AUTOMATIONROOT\emulator\cdEmulate-ci.bat"
	write-host "$ciProcess (default)"
}

# Check for customised Delivery process
Write-Host "[$scriptName]   cdProcess           : " -NoNewline
if (Test-Path "$solutionRoot\cdEmulate-deliver.bat") {
	$cdProcess="$solutionRoot\cdEmulate-deliver.bat"
	write-host "$cdProcess (override)"
} else {
	$cdProcess="$AUTOMATIONROOT\emulator\cdEmulate-deliver.bat"
	write-host "$cdProcess (default)"
}

# If a solution properties file exists, load the properties
if (Test-Path "$solutionRoot\CDAF.solution") {
	write-host
	write-host "[$scriptName] Load Solution Properties $solutionRoot\CDAF.solution"
	& .\$automationHelper\Transform.ps1 "$solutionRoot\CDAF.solution" | ForEach-Object { invoke-expression $_ }
}

# CDM-70 : If the Solution is not defined in the CDAF.solution file, use current working directory
# In Jenkins parameter is JOB_NAME 
if (! $solutionName) {
	$solutionName = $(Get-Item -Path .).Name
	write-host
	write-host "[$scriptName] Solution name (solutionName) not defined in $solutionRoot\CDAF.solution, defaulting to current working directory, $solutionName"
}

# Process Build and Package
& $ciProcess $solutionName $environmentBuild $buildNumber $revision $AUTOMATIONROOT $workDirLocal $workDirRemote $ACTION
if(!$?){ exitWithCode $ciProcess }

# Do not process Remote and Local Tasks if the action is just clean
if ( $ACTION -eq "clean" ) {
	write-host
	write-host "[$scriptName] No Delivery Action attempted when clean only action"
} else {
	& $cdProcess $solutionName $environmentDelivery $buildNumber $revision $AUTOMATIONROOT $workDirLocal $workDirRemote $ACTION
	if(!$?){ exitWithCode $ciProcess }
}

write-host
write-host "[$scriptName] ------------------"
write-host "[$scriptName] Emulation Complete"
write-host "[$scriptName] ------------------"
write-host
