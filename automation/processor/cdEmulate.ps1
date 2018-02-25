# Override function used in entry points
function exceptionExit ($taskName) {
    write-host "`n[$scriptName] --- Emulation Error Handling ---" -ForegroundColor Red
    write-host "`n[$scriptName] This logging will not appear in toolset" -ForegroundColor Red
    write-host "`n[$scriptName] $taskName failed!" -ForegroundColor Red
    write-host "[$scriptName]   Returning errorlevel (-2) to emulation wrapper" -ForegroundColor Magenta
    exit 2034
}

$scriptName = $MyInvocation.MyCommand.Name

$ACTION = $args[0]
Write-Host "[$scriptName]   ACTION              : $ACTION"

$AUTOMATIONROOT = $args[1]
if ($AUTOMATIONROOT) {
	Write-Host "[$scriptName]   AUTOMATIONROOT      : $AUTOMATIONROOT"
} else {
	$AUTOMATIONROOT = 'automation'
	Write-Host "[$scriptName]   AUTOMATIONROOT      : $AUTOMATIONROOT (default)"
}

# Use a simple text file (buildnumber.counter) for incrimental build number
if ( Test-Path "$env:USERPROFILE\buildnumber.counter" ) {
	$buildNumber = Get-Content "$env:USERPROFILE\buildnumber.counter"
} else {
	$buildNumber = 0
}
[int]$buildnumber = [convert]::ToInt32($buildNumber)
if ( $ACTION -ne "cdonly" ) { # Do not incriment when just deploying
	$buildNumber += 1
}
Out-File "$env:USERPROFILE\buildnumber.counter" -InputObject $buildNumber
Write-Host "[$scriptName]   buildNumber         : $buildNumber"
$revision = 'master'
Write-Host "[$scriptName]   revision            : $revision"
$release = 'emulatioon-release' 
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

# If environment variable over-rides all other determinations
$environmentDelivery = "$Env:environmentDelivery"
if ($environmentDelivery ) {
	Write-Host "[$scriptName]   environmentDelivery : $environmentDelivery (loaded from `$Env:environmentDelivery)"
} else {
	# Check for customised Delivery environment process
	if (Test-Path "$solutionRoot\deliveryEnv.ps1") {
		$environmentDelivery = $(& $solutionRoot\deliveryEnv.ps1 $AUTOMATIONROOT $solutionRoot)
		Write-Host "[$scriptName]   environmentDelivery : $environmentDelivery (from $solutionRoot\deliveryEnv.ps1)"
	} else {
		# Set default depending on domain membership
		if ((gwmi win32_computersystem).partofdomain -eq $true) {
			$environmentDelivery = 'WINDOWS'
		} else {
			$environmentDelivery = 'WORKGROUP'
		}
		Write-Host "[$scriptName]   environmentDelivery : $environmentDelivery (default)"
	}
}

# Attempt solution name loading, error is not found
try {
	$solutionName=$(& .\$AUTOMATIONROOT\remote\getProperty.ps1 $solutionRoot\CDAF.solution 'solutionName')
	if(!$?){  }
} catch {  }
if ( $solutionName ) {
	Write-Host "[$scriptName]   solutionName        : $solutionName (from ${solutionRoot}\CDAF.solution)"
} else {
	write-host "[$scriptName] Solution name (solutionName) not defined in ${solutionRoot}\CDAF.solution!" -ForegroundColor Red
    write-host "[$scriptName]   Exit with `$LASTEXITCODE 1" -ForegroundColor Magenta
    $host.SetShouldExit(1) # Returning exit code to DOS
    exit
}
	
$workDirLocal = 'TasksLocal'
Write-Host "[$scriptName]   workDirLocal        : $workDirLocal (default, see readme for changing this location)"

if ( $ACTION ) { # Do not list configuration instructions when an action is passed
	write-host "`n[$scriptName] Action is $ACTION"
} else {
	write-host "`n[$scriptName] ---------- CI Toolset Configuration Guide -------------`n"
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
    write-host '  In .gitlab-ci.yml (in the root of the repository) add the following hook into the CI job, see example in sample folder'
    write-host "    script: `"automation/processor/buildPackage.bat %CI_BUILD_ID% %CI_BUILD_REF_NAME%`""
	write-host "`n[$scriptName] -------------------------------------------------------"
}
# Process Build and Package
if ( $ACTION -eq "cdonly" ) { # Case insensitive
	Write-Host "[$scriptName] Action is $ACTION so skipping build and package (CI) process"
} else {
	& $ciProcess $buildNumber $revision $ACTION
	if($LASTEXITCODE -ne 0){
	    write-host "[$scriptName] CI_NON_ZERO_EXIT $ciProcess $buildNumber $revision $ACTION" -ForegroundColor Magenta
	    write-host "[$scriptName]   `$host.SetShouldExit($LASTEXITCODE)" -ForegroundColor Red
	    $host.SetShouldExit($LASTEXITCODE) # Returning exit code to DOS
	    exit
	}
	if(!$?){ exceptionExit "$ciProcess $buildNumber $revision $ACTION" }
}
	
if ( $ACTION ) {
	if ( $ACTION -eq "cdonly" ) {
		write-host "`n[$scriptName] Instruction listing skipped when action ($ACTION) passed"
		$execCD = 'yes'
	} else {
		write-host "`n[$scriptName] No Delivery attempted when action ($ACTION) passed"
	}
} else {
	$execCD = 'yes'
	write-host "`n[$scriptName] ---------- Artefact Configuration Guide -------------`n"
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
	write-host "`n[$scriptName] ---------- CD Toolset Configuration Guide -------------`n"
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
}

if ( $execCD -eq 'yes' ) {
	& $cdProcess $environmentDelivery $release
	if($LASTEXITCODE -ne 0){
	    write-host "[$scriptName] CD_NON_ZERO_EXIT $cdProcess $environmentDelivery $release" -ForegroundColor Magenta
	    write-host "[$scriptName]   `$host.SetShouldExit($LASTEXITCODE)" -ForegroundColor Red
	    $host.SetShouldExit($LASTEXITCODE) # Returning exit code to DOS
	    exit
	}
	if(!$?){ exceptionExit "$cdProcess $environmentDelivery $release" }
}

write-host "`n[$scriptName] ------------------"
write-host "[$scriptName] Emulation Complete"
write-host "[$scriptName] ------------------`n"
$error.clear()
exit 0