Param (
	[string]$boxname,
	[string]$diskFrom,
	[string]$diskto,
	[string]$emailTo,
	[string]$smtpServer,
	[string]$emailFrom
)
$scriptName = 'cloneDisk.ps1'
cmd /c "exit 0"

# Use executeIgnoreExit to only trap powershell errors, use executeExpression to trap all errors, including $LASTEXITCODE
function execute ($expression) {
	$error.clear()
	Write-Host "[$(date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "`$? = $?"; emailAndExit 1050 }
	} catch { echo $_.Exception|format-list -force; emailAndExit 1051 }
    if ( $error[0] ) { Write-Host "`$error[0] = $error"; emailAndExit 1052 }
}

function executeExpression ($expression) {
	execute $expression
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
    	Write-Host "[$scriptName] ERROR! Exiting with `$LASTEXITCODE = $LASTEXITCODE" -foregroundcolor "red";
    	emailAndExit $LASTEXITCODE
	}
}

function executeIgnoreExit ($expression) {
	execute $expression
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] Warning `$LASTEXITCODE = $LASTEXITCODE" -foregroundcolor "yellow"; cmd /c "exit 0" }
}

# Exception Handling email sending
function emailAndExit ($exitCode) {
	if ($smtpServer) {
		Send-MailMessage -To "$emailTo" -From "$emailFrom" -Subject "[$scriptName] ERROR $exitCode" -SmtpServer "$smtpServer"
	}
	exit $exitCode
}

# Informational email notification 
function emailProgress ($subject) {
	if ($smtpServer) {
		Send-MailMessage -To "$emailTo" -From "$emailFrom" -Subject "[$scriptName] $subject" -SmtpServer "$smtpServer"
	}
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($boxname) {
    Write-Host "[$scriptName] boxname     : $boxname"
} else {
    Write-Host "[$scriptName] boxname not supplied"; exit 7020
}

if ($diskFrom) {
    Write-Host "[$scriptName] diskFrom    : $diskFrom"
} else {
    Write-Host "[$scriptName] diskFrom not supplied"; exit 7021
}

if ($diskTo) {
    Write-Host "[$scriptName] diskTo      : $diskTo"
} else {
    Write-Host "[$scriptName] diskTo not supplied"; exit 7022
}

if ($emailTo) {
    Write-Host "[$scriptName] emailTo     : $emailTo"
} else {
    Write-Host "[$scriptName] emailTo     : (not specified, email will not be attempted)"
}

if ($smtpServer) {
    Write-Host "[$scriptName] smtpServer  : $smtpServer"
} else {
    Write-Host "[$scriptName] smtpServer  : (not specified, email will not be attempted)"
}

if ($emailFrom) {
    Write-Host "[$scriptName] emailFrom   : $emailFrom"
} else {
    Write-Host "[$scriptName] emailFrom   : (not specified, email will not be attempted)"
}

emailProgress "Starting disk copy from $diskFrom and clone to $diskDir"

Write-Host "[$scriptName] From Hyper-V image"
executeExpression "cp $diskFrom $diskTo"

$diskDir = "D:\VMs\$boxname" # This is the default used in AtlasPackage
& "C:\Program Files\Oracle\Virtualbox\VBoxmanage.exe" clonehd "$diskTo" "$diskDir\$boxname.vdi" --format vdi

emailProgress "COMLETE disk copy from $diskFrom and clone to $diskDir"

Write-Host "`n[$scriptName] ---------- stop ----------"
