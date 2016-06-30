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
$environmentBuild = [Environment]::GetEnvironmentVariable('environmentBuild', 'Machine')
if ($environmentBuild ) {
	Write-Host "[$scriptName]   environmentBuild    : $environmentBuild"
} else {
	$environmentBuild    = "BUILD"
	Write-Host "[$scriptName]   environmentBuild    : $environmentBuild (default)"
}

$environmentDelivery = [Environment]::GetEnvironmentVariable('environmentDelivery', 'Machine')
if ($environmentDelivery ) {
	Write-Host "[$scriptName]   environmentDelivery : $environmentDelivery"
} else {
	$environmentDelivery = "WINDOWS"
	Write-Host "[$scriptName]   environmentDelivery : $environmentDelivery (default)"
}

# Use timestamp to ensure unique build number and emulate the revision ID (source control)
# In Bamboo parameter is  ${bamboo.buildNumber}
$buildNumber=get-date -f MMddHHmmss
$revision=get-date -f HHmmss
Write-Host "[$scriptName]   buildNumber         : $buildNumber"
Write-Host "[$scriptName]   revision            : $revision"

# Check for user defined solution folder, i.e. outside of automation root, if found override solution root
Write-Host "[$scriptName]   solutionRoot        : " -NoNewline
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

# Check for customised CI process
Write-Host "[$scriptName]   ciProcess           : " -NoNewline
if (Test-Path "$solutionRoot\ciProcess.bat") {
	$ciProcess="$solutionRoot\ciProcess.bat"
	$ciInstruction="$solutionRoot/ciProcess.bat"
	write-host "$ciProcess (override)"
} else {
	$ciProcess="$AUTOMATIONROOT\processor\ciProcess.bat"
	$ciInstruction="$AUTOMATIONROOT/processor/ciProcess.bat"
	write-host "$ciProcess (default)"
}

# Check for customised Delivery process
Write-Host "[$scriptName]   cdProcess           : " -NoNewline
if (Test-Path "$solutionRoot\deliverProcess.bat") {
	$cdProcess="$solutionRoot\deliverProcess.bat"
	write-host "$cdProcess (override)"
} else {
	$cdProcess="$AUTOMATIONROOT\processor\deliverProcess.bat"
	write-host "$cdProcess (default)"
}
# Packaging will ensure either the override or default delivery process is in the workspace root
$cdInstruction="deliverProcess.bat"

# CDM-70 : If the Solution is not defined in the CDAF.solution file, use current working directory
# In Jenkins parameter is JOB_NAME 
# Attempt solution name loading, not an error if not found
try {
	$solutionName=$(& .\$automationHelper\getProperty.ps1 $solutionRoot\CDAF.solution 'solutionName')
	if(!$?){  }
} catch {  }
if (! $solutionName) {
	$solutionName = $(Get-Item -Path .).Name
	write-host
	write-host "[$scriptName] Solution name (solutionName) not defined in $solutionRoot\CDAF.solution, defaulting to current working directory, $solutionName"
}

# Do not list configuration instructions when performing clean
if ( $ACTION -ne "clean" ) {
	write-host
	write-host "[$scriptName] ---------- CI Toolset Configuration Guide -------------"
	write-host
    write-host 'For TeamCity ...'
    write-host "  Command Executable  : $ciInstruction"
    write-host "  Command parameters  : $solutionName $environmentBuild %build.number% %build.vcs.number% $AUTOMATIONROOT $workDirLocal $workDirRemote $ACTION"
    write-host
    write-host 'For Bamboo ...'
    write-host "  Script file         : $ciProcess"
    write-host "  Argument            : $solutionName $environmentBuild `${bamboo.buildNumber} `${bamboo.repository.revision.number} $AUTOMATIONROOT $workDirLocal $workDirRemote $ACTION"
    write-host
    write-host 'For Jenkins ...'
    write-host "  Command : $AUTOMATIONROOT\buildandpackage\buildProjects.bat $solutionName $environmentBuild %BUILD_NUMBER% %SVN_REVISION% $AUTOMATIONROOT $workDirLocal $workDirRemote $ACTION"
    write-host
    write-host 'For BuildMaster ...'
    write-host "  Executable file     : SourcesDirectory + `"$ciProcess`""
    write-host "  Arguments           : $solutionName $environmentBuild `${BuildNumber} $revision $AUTOMATIONROOT $workDirLocal $workDirRemote $ACTION"
    write-host
    write-host 'For Team Foundation Server/Visual Studio Team Services'
    write-host '  XAML ...'
    write-host "    Command Filename  : SourcesDirectory + `"$ciProcess`""
    write-host "    Command arguments : `"$solutionName + $environmentBuild + `" + BuildDetail.BuildNumber + `" + $revision + $AUTOMATIONROOT + $workDirLocal + $workDirRemote + $ACTION`""
    write-host
    write-host '  Team Build (vNext)...'
    write-host '    Use the visual studio template and delete the nuget and VS tasks.'
	write-host '    NOTE: The BUILD DEFINITION NAME must not contain spaces in the name as it is the directory.'
	write-host '          Set the build number $(rev:r)'
	write-host '    Recommend using the navigation UI to find the entry script.'
	write-host '    Cannot use %BUILD_SOURCEVERSION% with external Git'
    write-host "    Command Filename  : $ciProcess"
    write-host "    Command arguments : $solutionName $environmentBuild %BUILD_BUILDNUMBER% %BUILD_SOURCEVERSION% $AUTOMATIONROOT $workDirLocal $workDirRemote $ACTION"
	write-host "    Working folder    : repositoryname"
    write-host
	write-host "[$scriptName] -------------------------------------------------------"
}
# Process Build and Package
& $ciProcess $solutionName $environmentBuild $buildNumber $revision $AUTOMATIONROOT $workDirLocal $workDirRemote $ACTION
if(!$?){ exitWithCode $ciProcess }

if ( $ACTION -ne "clean" ) {
	write-host
	write-host "[$scriptName] ---------- Artefact Configuration Guide -------------"
	write-host
	write-host 'Configure artefact retention patterns to retain package and local tasks'
	write-host
	write-host 'For Bamboo ...'
	write-host '  Name    : TasksLocal'
	write-host '  Pattern : TasksLocal/**'
	write-host '  Name    : Package '
	write-host '  Pattern : *.zip'
	write-host
	write-host 'For VSTS / TFS 2015 ...'
	write-host '  Use the combination of Copy files and Retain Artefacts from Visual Studio Solution Template'
	write-host '  Source Folder   : $(Agent.BuildDirectory)\s'
	write-host '  Copy files task : TasksLocal/**'
	write-host '                    *.zip'
}

# Do not process Remote and Local Tasks if the action is just clean
if ( $ACTION -eq "clean" ) {
	write-host
	write-host "[$scriptName] No Delivery Action attempted when clean only action"
} else {
	write-host
	write-host "[$scriptName] ---------- CD Toolset Configuration Guide -------------"
	write-host
	write-host 'Note: artifact retention typically does include file attribute for executable, so'
	write-host '  set the first step of deploy process to make all scripts executable'
	write-host '  chmod +x ./*/*.sh'
	write-host
	write-host 'For TeamCity ...'
	write-host "  Command Executable  : $workDirLocal/$cdInstruction"
	write-host "  Command parameters  : $solutionName $environmentDelivery %build.number% %build.vcs.number% $AUTOMATIONROOT $workDirLocal $workDirRemote"
	write-host
	write-host 'For Bamboo ...'
	write-host '  Warning! set Deployment project name to solution name, with no spaces.'
	write-host '  note: set the release tag to (assuming no releases performed, otherwise, use the release number already set)'
	write-host '  build-${bamboo.buildNumber} deploy-1'
	write-host "  Script file         : `${bamboo.build.working.directory}\$workDirLocal\$cdInstruction"
	write-host "  Argument            : `${bamboo.deploy.project} `${bamboo.deploy.environment} `${bamboo.buildNumber} `${bamboo.deploy.release} $AUTOMATIONROOT $workDirLocal $workDirRemote"
	write-host
	write-host 'For Jenkins ...'
	write-host "  Command             : $workDirLocal\$cdInstruction $solutionName $environmentDelivery %BUILD_NUMBER% %SVN_REVISION% $AUTOMATIONROOT $workDirLocal $workDirRemote"
	write-host
	write-host 'For BuildMaster ...'
	write-host "  Executable file     : $workDirLocal\$cdInstruction"
	write-host "  Arguments           : $solutionName $environmentDelivery `${BuildNumber} $revision $AUTOMATIONROOT $workDirLocal $workDirRemote"
	write-host
	write-host 'For Team Foundation Server/Visual Studio Team Services'
	write-host '  For XAML ...'
	write-host "    Command Filename  : SourcesDirectory + `"\$workDirLocal\$cdInstruction`""
	write-host "    Command arguments : `" + $solutionName + $environmentDelivery + `" + BuildDetail.BuildNumber + `" $revision + $AUTOMATIONROOT + $workDirLocal + $workDirRemote`""
	write-host
	write-host '  For Team Release ...'
	write-host '  Check the default queue for Environment definition.'
	write-host '  Run an empty release initially to load the workspace, which can then be navigated to for following configuration.'
	write-host "    Command Filename  : `$(System.DefaultWorkingDirectory)/$solutionName/drop/$workDirLocal/$cdInstruction"
	write-host "    Command arguments : $solutionName `$RELEASE_ENVIRONMENTNAME `${BUILD_BUILDNUMBER} `${BUILD_SOURCEVERSION} $automationRoot $workDirLocal $workDirRemote"
	write-host "    Working folder    : `$(System.DefaultWorkingDirectory)/$solutionName/drop"
	write-host
	write-host "[$scriptName] -------------------------------------------------------"
	& $cdProcess $solutionName $environmentDelivery $buildNumber $revision $AUTOMATIONROOT $workDirLocal $workDirRemote $ACTION
	if(!$?){ exitWithCode $ciProcess }
}
write-host
write-host "[$scriptName] ------------------"
write-host "[$scriptName] Emulation Complete"
write-host "[$scriptName] ------------------"
write-host
