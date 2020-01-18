Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Security

# Override function used in entry points
function exceptionExit ($taskName) {
    write-host "`n[$scriptName] --- exceptionExit ---" -ForegroundColor Red
    write-host "[$scriptName]   Typically this represents a CDAFramework error, i.e. untrapped exception" -ForegroundColor Red
    write-host "[$scriptName]   $taskName failed!" -ForegroundColor Red
    write-host "[$scriptName]   Returning errorlevel (2035) to emulation wrapper" -ForegroundColor Magenta
    write-host "`n[$scriptName] --- exceptionExit ---" -ForegroundColor Red
    exit 2035
}

# Trap Command Failures
function failureExit ($taskName) {
    write-host "`n[$scriptName] --- failureExit ---" -ForegroundColor Red
    write-host "[$scriptName]   This can occur when standard error is not trapped in Server 2019" -ForegroundColor Red
    write-host "[$scriptName]   $taskName failed!" -ForegroundColor Red
    write-host "[$scriptName]   Returning errorlevel (2034) to emulation wrapper" -ForegroundColor Magenta
    write-host "[$scriptName] --- failureExit ---" -ForegroundColor Red
    exit 2034
}

$scriptName = $MyInvocation.MyCommand.Name

$ACTION = $args[0]
Write-Host "[$scriptName]   ACTION              : $ACTION (coded options cionly, buildonly, packageonly or cdonly)"

$AUTOMATIONROOT = $args[1]
if ($AUTOMATIONROOT) {
	Write-Host "[$scriptName]   AUTOMATIONROOT      : $AUTOMATIONROOT"
} else {
	$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
	$AUTOMATIONROOT = split-path -parent $scriptPath
	Write-Host "[$scriptName]   AUTOMATIONROOT      : $AUTOMATIONROOT (default)"
}
$env:CDAF_AUTOMATION_ROOT = $AUTOMATIONROOT

$counterFile = "$env:USERPROFILE\buildnumber.counter"
# Use a simple text file ($counterFile) for incrimental build number, using the same logic as entry.ps1
if ( Test-Path "$counterFile" ) {
	$buildNumber = Get-Content "$counterFile"
} else {
	$buildNumber = 0
}
[int]$buildnumber = [convert]::ToInt32($buildNumber)
if ( $ACTION -ne "cdonly" ) { # Do not incriment when just deploying
	$buildNumber += 1
}
Set-Content "$counterFile" "$buildNumber"
Write-Host "[$scriptName]   buildNumber         : $buildNumber"
if ( $env:CDAF_BRANCH_NAME ) {
	$revision = $env:CDAF_BRANCH_NAME
} else {
	$revision = 'feature'
}
Write-Host "[$scriptName]   revision            : $revision"
$release = 'emulation-release' 
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
if ($CDAF_DELIVERY) { # check for DOS variable and load as PowerShell environment variable
	$Env:CDAF_DELIVERY = "$CDAF_DELIVERY"
} else {
	$CDAF_DELIVERY = "$Env:CDAF_DELIVERY"
}
if ($CDAF_DELIVERY ) {
	Write-Host "[$scriptName]   CDAF_DELIVERY       : $CDAF_DELIVERY (loaded from `$Env:CDAF_DELIVERY)"
} else {
	# Check for customised Delivery environment process
	if (Test-Path "$solutionRoot\deliveryEnv.ps1") {
		$CDAF_DELIVERY = $(& $solutionRoot\deliveryEnv.ps1 $AUTOMATIONROOT $solutionRoot)
		Write-Host "[$scriptName]   CDAF_DELIVERY       : $CDAF_DELIVERY (from $solutionRoot\deliveryEnv.ps1)"
	} else {
		# Set default depending on domain membership
		if ((gwmi win32_computersystem).partofdomain -eq $true) {
			$CDAF_DELIVERY = 'WINDOWS'
		} else {
			$CDAF_DELIVERY = 'WORKGROUP'
		}
		Write-Host "[$scriptName]   CDAF_DELIVERY       : $CDAF_DELIVERY (default)"
	}
}

# Attempt solution name loading, error is not found
try {
	$solutionName=$(& $AUTOMATIONROOT\remote\getProperty.ps1 $solutionRoot\CDAF.solution 'solutionName')
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
	write-host "`n[$scriptName] Action is $ACTION" -ForegroundColor "Blue"
} else {
	write-host "`n[$scriptName] ---------- CI Toolset Configuration Guide -------------`n"
    write-host 'For TeamCity ...'
    write-host "  Command Executable  : $ciInstruction"
    write-host "  Command parameters  : %build.counter% %build.vcs.number%"
    write-host
    write-host 'For Bamboo ...'
    write-host "  Script file         : $ciProcess"
    write-host "  Argument            : `${bamboo.buildNumber} `${bamboo.repository.branch.name}"
    write-host
    write-host 'For Jenkins ...'
    write-host "  Command : $ciProcess %BUILD_NUMBER% %SVN_REVISION%"
    write-host
    write-host 'For BuildMaster ... (use "Get Source from Git Repository" to download to $WorkingDirectory, then "PSExec" as follows)'
	write-host '  Set workspace       : cd $WorkingDirectory'
	write-host "  Run CI Process      : $ciProcess `${BuildNumber}"
    write-host
    write-host 'For Azure DevOps/Server (formerly Visual Studio Team Services (VSTS)/Team Foundation Server (TFS))'
    write-host '  Recommend using azure-pipelines (see samples folder)'
    write-host '    Use the visual studio template and delete the nuget and VS tasks.'
	write-host '    NOTE: The BUILD DEFINITION NAME must not contain spaces in the name as it is the directory.'
	write-host '          recommend using solution name, then the Release instructions can be used unchanged.'
	write-host '          Set the build number $(rev:r)'
	write-host '    Recommend using the navigation UI to find the entry script.'
    write-host "    Command Filename  : $ciProcess"
    write-host "    Command arguments : %BUILD_BUILDNUMBER% %BUILD_SOURCEBRANCHNAME%"
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
	if ( $ACTION ) { # $AUTOMATIONROOT can only be passed if $ACTION is also passed, don't try to pass when not set
		& $ciProcess $buildNumber $revision $ACTION $solutionName $AUTOMATIONROOT
		if($LASTEXITCODE -ne 0){
		    write-host "[$scriptName] CI_NON_ZERO_EXIT $ciProcess $buildNumber $revision $ACTION $solutionName $AUTOMATIONROOT" -ForegroundColor Magenta
		    write-host "[$scriptName]   `$host.SetShouldExit($LASTEXITCODE)" -ForegroundColor Red
		    $host.SetShouldExit($LASTEXITCODE) # Returning exit code to DOS
		    exit
		}
		if(!$?){ failureExit "$ciProcess $buildNumber $revision $ACTION $solutionName $AUTOMATIONROOT" }
	} else {
		& $ciProcess $buildNumber $revision
		if($LASTEXITCODE -ne 0){
		    write-host "[$scriptName] CI_NON_ZERO_EXIT $ciProcess $buildNumber $revision" -ForegroundColor Magenta
		    write-host "[$scriptName]   `$host.SetShouldExit($LASTEXITCODE)" -ForegroundColor Red
		    $host.SetShouldExit($LASTEXITCODE) # Returning exit code to DOS
		    exit
		}
		if(!$?){ failureExit "$ciProcess $buildNumber $revision" }
	}
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
    write-host 'For TeamCity ...'
    write-host "  Artifact paths : TasksLocal => TasksLocal"
    write-host "                 : *.zip"
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
    write-host 'For Azure DevOps/Server (formerly Visual Studio Team Services (VSTS)/Team Foundation Server (TFS))'
    write-host '  Recommend using azure-pipelines (see samples folder), use following if configuring manually'
	write-host '    Use the combination of Copy files and Retain Artefacts from Visual Studio Solution Template'
	write-host '    Source Folder   : $(Agent.BuildDirectory)\s'
	write-host '    Copy files task : TasksLocal/**'
	write-host '                      *.zip'

	write-host "`n[$scriptName] ---------- CD Toolset Configuration Guide -------------`n"
	write-host
	write-host 'For TeamCity ...'
	write-host "  Dependencies -> Get artifacts from : 'build from the same chain'"
	write-host "                  Artifacts rules    : TasksLocal => TasksLocal"
	write-host
	write-host "  Command Executable  : $workDirLocal/$cdInstruction"
	write-host "  Command parameters  : %env.TEAMCITY_BUILDCONF_NAME% %build.number%"
	write-host
	write-host 'For Bamboo ...'
	write-host "  Script file         : `${bamboo.build.working.directory}\$workDirLocal\$cdInstruction"
	write-host "  Argument            : `${bamboo.deploy.environment} `${bamboo.deploy.release}"
	write-host
	write-host 'For Jenkins (each environment requires a literal definition) ...'
	write-host "  Command             : $workDirLocal\$cdInstruction <environment literal> %SVN_REVISION%"
	write-host
	write-host 'For BuildMaster ... (Use "Deploy Artifact" to download to $WorkingDirectory, then use "PSExec" as follows)'
	write-host '  Set workspace       : cd $WorkingDirectory'
	write-host "  Run Delivery        : $workDirLocal\$cdInstruction `${EnvironmentName} `${ReleaseNumber}"
	write-host
    write-host 'For Azure DevOps/Server (formerly Visual Studio Team Services (VSTS)/Team Foundation Server (TFS))'
	write-host '  Verify the queue for each Environment definition, and ensure Environment names do not contain spaces.'
	write-host '  Run an build with artefacts initially to load the workspace, which can then be navigated to for following configuration.'
	write-host '  From an empty release configuration, bind to the existing build and within the stage, add a "PowerShell" step.'
	write-host "    Command Filename    : `$(System.DefaultWorkingDirectory)/$solutionName/drop/$workDirLocal/delivery.ps1"
	write-host '    Command arguments   : "$(Release.EnvironmentName)" "$(Release.ReleaseName)"'
	write-host "    Working folder      : `$(System.DefaultWorkingDirectory)/$solutionName/drop"
	write-host "    Release name format : $solutionName-`$(Build.BuildNumber)"
	write-host "      For re-release    : $solutionName-`$(Build.BuildNumber)-`$(rev:r)"
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
	& $cdProcess $CDAF_DELIVERY $release
	if($LASTEXITCODE -ne 0){
	    write-host "[$scriptName] CD_NON_ZERO_EXIT $cdProcess $CDAF_DELIVERY $release" -ForegroundColor Magenta
	    write-host "[$scriptName]   `$host.SetShouldExit($LASTEXITCODE)" -ForegroundColor Red
	    $host.SetShouldExit($LASTEXITCODE) # Returning exit code to DOS
	    exit
	}
	if(!$?){ failureExit "$cdProcess $CDAF_DELIVERY $release" }
}

write-host "`n[$scriptName] ------------------"
write-host "[$scriptName] Emulation Complete"
write-host "[$scriptName] ------------------`n"
$error.clear()
exit 0