param (
	[Parameter(Position=0)]
	[string]$ACTION,
	[string]$RELEASE,
	[string]$OPT_ARG,
	[switch]$skipenv,
	[switch]$help
)

Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Security


# Consolidated Error processing function
#  required : error message
#  optional : exit code, if not supplied only error message is written
function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		if ( $exitcode ) {
			Write-Host "`n[$scriptName]$message" -ForegroundColor Red
		} else {
			Write-Host "`n[$scriptName] ERRMSG triggered without message parameter." -ForegroundColor Red
		}
	} else {
		if ( $exitcode ) {
			Write-Warning "`n[$scriptName]$message"
		} else {
			Write-Warning "`n[$scriptName] ERRMSG triggered without message parameter."
		}
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
	if ( $exitcode ) {
		if ( $env:CDAF_ERROR_DIAG ) {
			Write-Host "`n[$scriptName] Invoke custom diag `$env:CDAF_ERROR_DIAG = $env:CDAF_ERROR_DIAG`n"
			try {
				Invoke-Expression $env:CDAF_ERROR_DIAG
			    if(!$?) { Write-Host "[CDAF_ERROR_DIAG] `$? = $?" }
			} catch {
				$message = $_.Exception.Message
				$_.Exception | format-list -force
			}
		    if ( $LASTEXITCODE ) {
		    	if ( $LASTEXITCODE -ne 0 ) {
					Write-Host "[CDAF_ERROR_DIAG][EXIT] `$LASTEXITCODE is $LASTEXITCODE"
				}
			}
		}
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

if ( $help ) {
	Write-Host "`n[$scriptName] Usage: $scriptName [[-ACTION] <action>] [-RELEASE <release>] [-OPT_ARG <optional argument>] [-skipenv] [-help]`n"
	Write-Host "  -ACTION  Optional, positional (first argument). One of:"
	Write-Host "             cionly       build and package only"
	Write-Host "             buildonly    build only"
	Write-Host "             packageonly  package only"
	Write-Host "             cdonly       delivery only, build number is not incremented"
	Write-Host "           When not supplied, CI and CD are both executed and the action forwarded to build process."
	Write-Host "  -RELEASE Optional, forwarded to the delivery process (delivery.bat / release.ps1)."
	Write-Host "  -OPT_ARG Optional, forwarded to the delivery process (delivery.bat / release.ps1)."
	Write-Host "  -skipenv Do not load environment variables from .env in the solution root."
	Write-Host "  -help    Display this message and exit.`n"
	exit 0
}

# Check for user defined solution folder, i.e. outside of automation root, if found override solution root
foreach ($item in (Get-ChildItem -Path ".")) {
	if (Test-Path $item -PathType "Container") {
		if (Test-Path "$item\CDAF.solution") {
			$SOLUTIONROOT=$item
		}
	}
}
if ($SOLUTIONROOT) {
	$SOLUTIONROOT = (Get-Item $SOLUTIONROOT).FullName
}

if ( ! $skipenv -and $SOLUTIONROOT -and ( Test-Path "$SOLUTIONROOT\.env" )) {
	Write-Host "[$scriptName]   Loading environment variables from $SOLUTIONROOT\.env"
	Get-Content "$SOLUTIONROOT\.env" | ForEach-Object {
		if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
			[System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
		}
	}
}

if ($AUTOMATIONROOT) {
	Write-Host "[$scriptName]   ACTION              : $ACTION (options cionly, buildonly, packageonly or cdonly)"
} else {
	Write-Host "[$scriptName]   ACTION              : (not supplied, options cionly, buildonly, packageonly or cdonly)"
}

if ( $RELEASE ) {
	Write-Host "[$scriptName]   RELEASE             : $RELEASE (forwarded to delivery process)"
} else {
	Write-Host "[$scriptName]   RELEASE             : (not supplied)"
}

if ( $OPT_ARG ) {
	Write-Host "[$scriptName]   OPT_ARG             : $OPT_ARG (forwarded to delivery process)"
} else {
	Write-Host "[$scriptName]   OPT_ARG             : (not supplied)"
}

$counterFile = "$env:USERPROFILE\BUILDNUMBER.counter"
# Use a simple text file ($counterFile) for incrimental build number, using the same logic as entry.ps1
if ( Test-Path "$counterFile" ) {
	$BUILDNUMBER = Get-Content "$counterFile"
} else {
	$BUILDNUMBER = 0
}
[int]$BUILDNUMBER = [convert]::ToInt32($BUILDNUMBER)
if ( $ACTION -ne "cdonly" ) { # Do not incriment when just deploying
	$BUILDNUMBER += 1
}
Set-Content "$counterFile" "$BUILDNUMBER"
Write-Host "[$scriptName]   BUILDNUMBER         : $BUILDNUMBER (auto incrimented from $env:USERPROFILE\BUILDNUMBER.counter)"

if ( $env:CDAF_BRANCH_NAME ) {
	$REVISION = $env:CDAF_BRANCH_NAME
} else {
	$REVISION = 'release'
}
Write-Host "[$scriptName]   REVISION            : $REVISION"


$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$AUTOMATIONROOT = split-path -parent $scriptPath
Write-Host "[$scriptName]   AUTOMATIONROOT      : $AUTOMATIONROOT (default)"
$CDAF_CORE = "$AUTOMATIONROOT\remote"

# Check for user defined solution folder, i.e. outside of automation root, if found override solution root
Write-Host "[$scriptName]   SOLUTIONROOT        : " -NoNewline
if ($SOLUTIONROOT) {
	write-host "$SOLUTIONROOT (found $SOLUTIONROOT\CDAF.solution)"
} else {
	ERRMSG "[NO_SOLUTION_ROOT] No directory found containing CDAF.solution, please create a single occurrence of this file." 7710
}

# Attempt solution name loading, error if not found
try {
	$SOLUTION=$(& "$CDAF_CORE\getProperty.ps1" "$SOLUTIONROOT\CDAF.solution" 'solutionName')
	if(!$?){  }
} catch {  }
if ( $SOLUTION ) {
	Write-Host "[$scriptName]   SOLUTION            : $SOLUTION (from ${SOLUTIONROOT}\CDAF.solution)"
} else {
	ERRMSG "[$scriptName] Solution name (SOLUTION) not defined in ${SOLUTIONROOT}\CDAF.solution!" 7711
}

# If environment variable over-rides all other determinations
if ( $CDAF_DELIVERY ) { # check for DOS variable and load as PowerShell environment variable
	$env:CDAF_DELIVERY = "$CDAF_DELIVERY"
} else {
	$CDAF_DELIVERY = "$env:CDAF_DELIVERY"
}
if ( $CDAF_DELIVERY ) {
	Write-Host "[$scriptName]   CDAF_DELIVERY       : $CDAF_DELIVERY (loaded from `$Env:CDAF_DELIVERY)"
} else {
	# Check for customised Delivery environment process
	if ( Test-Path "$SOLUTIONROOT\deliveryEnv.ps1" ) {
		$CDAF_DELIVERY = $(& "$SOLUTIONROOT\deliveryEnv.ps1" "$AUTOMATIONROOT" "$SOLUTIONROOT")
		Write-Host "[$scriptName]   CDAF_DELIVERY       : $CDAF_DELIVERY (from $SOLUTIONROOT\deliveryEnv.ps1)"
	} else {
		# Set default depending on domain membership
		if ((gwmi win32_computersystem).partofdomain -eq $true) {
			$CDAF_DELIVERY = 'WINDOWS'
			Write-Host "[$scriptName]   CDAF_DELIVERY       : $CDAF_DELIVERY (derived from domain membership)"
		} else {
			$CDAF_DELIVERY = 'WORKGROUP'
			Write-Host "[$scriptName]   CDAF_DELIVERY       : $CDAF_DELIVERY (default)"
		}
	}
}

# Check for customised CI process
Write-Host "[$scriptName]   ciProcess           : " -NoNewline
if ( Test-Path "$SOLUTIONROOT\buildPackage.ps1" ) {
	$ciProcess="$SOLUTIONROOT\buildPackage.ps1"
	write-host "$ciProcess (override)"
} else {
	$ciProcess="$AUTOMATIONROOT\processor\buildPackage.ps1"
	write-host "$ciProcess (default)"
}

# Check for customised Delivery process
Write-Host "[$scriptName]   cdProcess           : " -NoNewline
if ( Test-Path "$SOLUTIONROOT\delivery.bat" ) {
	$cdProcess="$SOLUTIONROOT\delivery.bat"
	write-host "$cdProcess (override)"
} else {
	$artifactPrefix=$(& "$CDAF_CORE\getProperty.ps1" "$SOLUTIONROOT\CDAF.solution" 'artifactPrefix')
	if ( $artifactPrefix ) {
		$cdProcess = '.\release.ps1'
	} else {
		$cdProcess = "$AUTOMATIONROOT\processor\delivery.bat"
	}
	write-host "$cdProcess (default)"
}
# Packaging will ensure either the override or default delivery process is in the workspace root
$cdInstruction="delivery.bat"

if ( $ACTION ) { # Do not list configuration instructions when an action is passed
	write-host "`n[$scriptName] Action is $ACTION" -ForegroundColor "Blue"
}
# Process Build and Package
if ( $ACTION -eq "cdonly" ) { # Case insensitive
	Write-Host "[$scriptName] Action is $ACTION so skipping build and package (CI) process"
} else {

	& "$ciProcess" "$BUILDNUMBER" "$REVISION" "$ACTION"
	if($LASTEXITCODE -ne 0){
	    write-host "[$scriptName] CI_NON_ZERO_EXIT $ciProcess $BUILDNUMBER $REVISION $ACTION" -ForegroundColor Magenta
	    write-host "[$scriptName]   `$host.SetShouldExit($LASTEXITCODE)" -ForegroundColor Red
	    $host.SetShouldExit($LASTEXITCODE) # Returning exit code to DOS
	    exit
	}
	if(!$?){ failureExit "$ciProcess $BUILDNUMBER $REVISION $ACTION" }
}
	
if (( $ACTION -eq 'cionly' ) -or ( $ACTION -eq 'buildonly' ) -or ( $ACTION -eq 'packageonly' )) {
	write-host "`n[$scriptName] Halting, no Delivery attempted when action ($ACTION) passed"
	write-host "`n[$scriptName] ------------------"
	write-host "[$scriptName] Emulation Complete"
	write-host "[$scriptName] ------------------`n"
	$error.clear()
	exit 0
}

# Build delivery arguments positionally, never passing an empty middle argument because
# PowerShell drops empty strings when invoking native commands, which would shift OPT_ARG
$cdArgs = @("$CDAF_DELIVERY")
if ( $OPT_ARG -and ( ! $RELEASE )) {
	$RELEASE = 'Release' # delivery.ps1 default, used as placeholder to keep OPT_ARG in position
}
if ( $RELEASE ) { $cdArgs += "$RELEASE" }
if ( $OPT_ARG ) { $cdArgs += "$OPT_ARG" }

& "$cdProcess" @cdArgs
if($LASTEXITCODE -ne 0){
    write-host "[$scriptName] CD_NON_ZERO_EXIT $cdProcess $cdArgs" -ForegroundColor Magenta
    write-host "[$scriptName]   `$host.SetShouldExit($LASTEXITCODE)" -ForegroundColor Red
    $host.SetShouldExit($LASTEXITCODE) # Returning exit code to DOS
    exit
}
if(!$?){ failureExit "$cdProcess $cdArgs" }

write-host "`n[$scriptName] ------------------"
write-host "[$scriptName] Emulation Complete"
write-host "[$scriptName] ------------------`n"
$error.clear()
exit 0