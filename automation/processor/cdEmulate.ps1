# Override function used in entry points
function exitWithCode ($taskName) {
    write-host
    write-host "[$scriptName] --- Emulation Error Handling ---" -ForegroundColor Red
    write-host
    write-host "[$scriptName] This logging will not appear in toolset" -ForegroundColor Red
    write-host
    write-host "[$scriptName] $taskName failed!" -ForegroundColor Red
    write-host "[$scriptName]   Returning errorlevel (-2) to emulation wrapper" -ForegroundColor Magenta
    $host.SetShouldExit(-2)
    exit
}

$scriptName          = $MyInvocation.MyCommand.Name

$ACTION = $args[0]
Write-Host "[$scriptName]   ACTION              : $ACTION"

$AUTOMATIONROOT = $args[1]
if ($AUTOMATIONROOT) {
	Write-Host "[$scriptName]   AUTOMATIONROOT      : $AUTOMATIONROOT"
} else {
	$AUTOMATIONROOT = 'automation'
	Write-Host "[$scriptName]   AUTOMATIONROOT      : $AUTOMATIONROOT (default)"
}

# Use timestamp to ensure unique build number
$buildNumber = $(get-date -f hhmmss)
$buildNumber = $buildNumber.TrimStart('0')
Write-Host "[$scriptName]   buildNumber         : $buildNumber"
$revision = 'master' # Assuming source control is Git
Write-Host "[$scriptName]   revision            : $revision"
$release = '666' # Assuming Release is an integer
Write-Host "[$scriptName]   release             : $release"

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
if (Test-Path "$solutionRoot\buildPackage.bat") {
	$ciProcess="$solutionRoot\buildPackage.bat"
	$ciInstruction="$solutionRoot/buildPackage.bat"
	write-host "$ciProcess (override)"
} else {
	$ciProcess="$AUTOMATIONROOT\processor\buildPackage.bat"
	$ciInstruction="$AUTOMATIONROOT/processor/buildPackage.bat"
	write-host "$ciProcess (default)"
}

# Check for customised Delivery process
Write-Host "[$scriptName]   cdProcess           : " -NoNewline
if (Test-Path "$solutionRoot\delivery.bat") {
	$cdProcess="$solutionRoot\delivery.bat"
	write-host "$cdProcess (override)"
} else {
	$cdProcess="$AUTOMATIONROOT\processor\delivery.bat"
	write-host "$cdProcess (default)"
}
# Packaging will ensure either the override or default delivery process is in the workspace root
$cdInstruction="delivery.bat"

$environmentDelivery = "$Env:environmentDelivery"
if ($environmentDelivery ) {
	Write-Host "[$scriptName]   environmentDelivery : $environmentDelivery"
} else {
	$environmentDelivery = 'WINDOWS'
	Write-Host "[$scriptName]   environmentDelivery : $environmentDelivery (default)"
}

# Attempt solution name loading, error is not found
try {
	$solutionName=$(& .\$AUTOMATIONROOT\remote\getProperty.ps1 $solutionRoot\CDAF.solution 'solutionName')
	if(!$?){  }
} catch {  }
if ( $solutionName ) {
	Write-Host "[$scriptName]   solutionName        : $solutionName (from ${solutionRoot}\CDAF.solution)"
} else {
	write-host "[$scriptName] Solution name (solutionName) not defined in ${solutionRoot}\CDAF.solution!"
	exitWithCode "SOLUTION_NOT_FOUND"
}

$workDirLocal = 'TasksLocal'
Write-Host "[$scriptName]   workDirLocal        : $workDirLocal (default, see readme for changing this location)"

# Do not list configuration instructions when performing clean
if ( $ACTION -ne "clean" ) { # Case insensitive
	write-host
	write-host "[$scriptName] ---------- CI Toolset Configuration Guide -------------"
	write-host
    write-host 'For TeamCity ...'
    write-host "  Command Executable  : $ciInstruction"
    write-host "  Command parameters  : %build.number% %build.vcs.number%"
    write-host
    write-host 'For Bamboo ...'
    write-host "  Script file         : $ciProcess"
    write-host "  Argument            : `${bamboo.buildNumber} `${bamboo.repository.revision.number}"
    write-host
    write-host 'For Jenkins ...'
    write-host "  Command : $ciProcess %BUILD_NUMBER% %SVN_REVISION%"
    write-host
    write-host 'For BuildMaster ...'
    write-host "  Executable file     : $ciProcess"
    write-host "  Arguments           : `${BuildNumber}"
    write-host
    write-host 'For Team Foundation Server/Visual Studio Team Services'
    write-host '  XAML ...'
    write-host "    Command Filename  : SourcesDirectory + `"$ciProcess`""
    write-host "    Command arguments : BuildDetail.BuildNumber + revision"
    write-host
    write-host '  Team Build (vNext)...'
    write-host '    Use the visual studio template and delete the nuget and VS tasks.'
	write-host '    NOTE: The BUILD DEFINITION NAME must not contain spaces in the name as it is the directory.'
	write-host '          recommend using solution name, then the Release instructions can be used unchanged.'
	write-host '          Set the build number $(rev:r)'
	write-host '    Recommend using the navigation UI to find the entry script.'
	write-host '    Cannot use %BUILD_SOURCEVERSION% with external Git'
    write-host "    Command Filename  : $ciProcess"
    write-host "    Command arguments : %BUILD_BUILDNUMBER% %BUILD_SOURCEVERSION%"
    write-host
    write-host 'For GitLab (requires shell runner) ...'
    write-host '  In .gitlab-ci.yml (in the root of the repository) add the following hook into the CI job'
    write-host "    script: `"automation/processor/ciProcess.sh `${CI_BUILD_ID} `{CI_BUILD_REF_NAME}`""
    write-host
	write-host "[$scriptName] -------------------------------------------------------"
}
# Process Build and Package
& $ciProcess $buildNumber $revision $ACTION
if(!$?){ exitWithCode $ciProcess }

if ( $ACTION -ne "clean" ) {
	write-host
	write-host "[$scriptName] ---------- Artefact Configuration Guide -------------"
	write-host
	write-host 'Configure artefact retention patterns to retain package and local tasks'
	write-host
    write-host 'For Go ...'
    write-host '  Source        | Destination | Type'
	write-host '  *.gz          | package     | Build Artifact'
    write-host '  TasksLocal/** |             | Build Artifact'
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
	write-host 'For TeamCity (each environment requires a literal definiion) ...'
	write-host "  Command Executable  : $workDirLocal/$cdInstruction"
	write-host "  Command parameters  : <environment literal> %build.vcs.number%"
	write-host
	write-host 'For Bamboo ...'
	write-host "  Script file         : `${bamboo.build.working.directory}\$workDirLocal\$cdInstruction"
	write-host "  Argument            : `${bamboo.deploy.environment} `${bamboo.deploy.release}"
	write-host
	write-host 'For Jenkins (each environment requires a literal definition) ...'
	write-host "  Command             : $workDirLocal\$cdInstruction $solutionName <environment literal> %SVN_REVISION%"
	write-host
	write-host 'For BuildMaster ...'
	write-host "  Executable file     : $workDirLocal\$cdInstruction"
	write-host "  Arguments           : `${EnvironmentName} `${ReleaseNumber}"
	write-host
	write-host 'For Team Foundation Server/Visual Studio Team Services'
	write-host '  For XAML (lineal deploy only) ...'
	write-host "    Command Filename  : SourcesDirectory + `"\$workDirLocal\$cdInstruction`""
	write-host "    Command arguments : `" + $environmentDelivery`""
	write-host
	write-host '  For Team Release ...'
	write-host '  Verify the queue for each Environment definition, and ensure Environment names do not contain spaces.'
	write-host '  Run an empty release initially to load the workspace, which can then be navigated to for following configuration.'
	write-host "    Command Filename  : `$(System.DefaultWorkingDirectory)/$solutionName/drop/$workDirLocal/$cdInstruction"
	write-host "    Command arguments : %RELEASE_ENVIRONMENTNAME% %RELEASE_RELEASENAME%"
	write-host "    Working folder    : `$(System.DefaultWorkingDirectory)/$solutionName/drop"
	write-host
    write-host 'For GitLab (requires shell runner) ...'
    write-host '  If using the sample .gitlab-ci.yml simply clone and change the Environment literal'
	write-host '  variables:'
	write-host '    ENV: "<environment>"'
    write-host "    script: `"$workDirLocal/$cdInstruction `${ENV} `${CI_PIPELINE_ID}`""
	write-host '    environment: <environment>'
   	write-host
	write-host "[$scriptName] -------------------------------------------------------"

	& $cdProcess $environmentDelivery $release
	if(!$?){ exitWithCode $ciProcess }
}
write-host
write-host "[$scriptName] ------------------"
write-host "[$scriptName] Emulation Complete"
write-host "[$scriptName] ------------------"
write-host
