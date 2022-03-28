Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Security

# Consolidated Error processing function
function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Red
	} else {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Yellow
	}

	if ( $env:CDAF_DEBUG_LOGGING ) {
		Write-Host "`n[$scriptName] Print Debug Logging `$env:CDAF_DEBUG_LOGGING`n"
		Write-HOst $env:CDAF_DEBUG_LOGGING
	}

	if ( $error ) {
		$i = 0
		foreach ( $item in $Error )
		{
			Write-Host "`$Error[$i] $item"
			$i++
		}
		$Error.clear()
	}
	if ( $env:CDAF_ERROR_DIAG ) {
		Write-Host "`n[$scriptName] Invoke custom diag `$env:CDAF_ERROR_DIAG = $env:CDAF_ERROR_DIAG`n"
		Invoke-Expression $env:CDAF_ERROR_DIAG
	}
	if ( $exitcode ) {
		Write-Host "`n[$scriptName] Exit with LASTEXITCODE = $exitcode`n" -ForegroundColor Red
		exit $exitcode
	}
}

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
	ERRMSG "[NO_SOLUTION_ROOT] No directory found containing CDAF.solution, please create a single occurrence of this file." 7611
}

# Check for customised CI process
Write-Host "[$scriptName]   ciProcess           : " -NoNewline
if (Test-Path "$solutionRoot\buildPackage.bat") {
	$ciProcess="$solutionRoot\buildPackage.bat"
	$ciInstruction="$solutionRoot/buildPackage.bat"
	write-host "$ciProcess (override)"
} else {
	$ciProcess="$AUTOMATIONROOT\ci.bat"
	$ciInstruction="$AUTOMATIONROOT\ci.bat"
	write-host "$ciProcess (default)"
}

# Check for customised Delivery process
Write-Host "[$scriptName]   cdProcess           : " -NoNewline
if (Test-Path "$solutionRoot\delivery.bat") {
	$cdProcess="$solutionRoot\delivery.bat"
	write-host "$cdProcess (override)"
} else {
	$artifactPrefix=$(& $AUTOMATIONROOT\remote\getProperty.ps1 $solutionRoot\CDAF.solution 'artifactPrefix')
	if ( $artifactPrefix ) {
		$cdProcess = '.\release.ps1'
	} else {
		$cdProcess = "$AUTOMATIONROOT\processor\delivery.bat"
		write-host "$cdProcess (default)"
	}
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