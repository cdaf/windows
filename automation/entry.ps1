Param (
	[string]$BUILDNUMBER,
	[string]$BRANCH,
	[string]$ACTION,
	[string]$AUTOMATIONROOT
)

Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Security

cmd /c "exit 0"
$error.clear()
$scriptName = 'entry.ps1'

# Mirror what entry.bat does
Write-Host "[$scriptName] --------------------"
Write-Host "[$scriptName] Git workspace processing"
Write-Host "[$scriptName]   BUILDNUMBER    : $BUILDNUMBER"
Write-Host "[$scriptName]   BRANCH         : $BRANCH"
Write-Host "[$scriptName]   ACTION         : $ACTION"

if ($AUTOMATIONROOT) {
    Write-Host "[$scriptName]   AUTOMATIONROOT : $AUTOMATIONROOT"
} else {
	$AUTOMATIONROOT = split-path -parent $MyInvocation.MyCommand.Definition
    Write-Host "[$scriptName]   AUTOMATIONROOT : $AUTOMATIONROOT (not supplied, derived from invocation)"
}

try {
	& $AUTOMATIONROOT\processor\gitProcess.ps1 $AUTOMATIONROOT $BUILDNUMBER $BRANCH $ACTION
	if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1211 }
} catch {
	Write-Host "[$scriptName][EXCEPTION] List exception and error array (if populated) and exit with LASTEXITCODE 1212" -ForegroundColor Red
	Write-Host $_.Exception|format-list -force
	if ( $error ) { Write-Host "[$scriptName][ERROR] `$Error = $Error" ; $Error.clear() }
	exit 1212
}
if ( $LASTEXITCODE ) {
	if ( $LASTEXITCODE -ne 0 ) {
		Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red
		if ( $error ) { Write-Host "[$scriptName][ERROR] `$Error = $Error" ; $Error.clear() }
		exit $LASTEXITCODE
	} else {
		if ( $error ) {
			Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
			Write-Host "[$scriptName][WARN] `$Error = $Error" ; $Error.clear()
		}
	} 
} else {
	if ( $error ) {
		if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
			Write-Host "[$scriptName][ERROR] `$Error = $error"; $Error.clear()
			Write-Host "[$scriptName][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting with LASTEXITCODE 1213 ..."; exit 1213
		} else {
			Write-Host "$error" ; $Error.clear()
		}
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0