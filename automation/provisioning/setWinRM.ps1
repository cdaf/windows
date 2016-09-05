# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
}


$scriptName = 'setStaticIP.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$URI = $args[0]
if ($URI) {
    Write-Host "[$scriptName] URI   : $URI"
} else {
    Write-Host "[$scriptName] URI not supplied, valid example winrm/config/winrs"
    Write-Host "[$scriptName] Exiting with exit code 100"
    exit 100
}

$name = $args[1]
if ($name) {
    Write-Host "[$scriptName] name  : $name"
} else {
    Write-Host "[$scriptName] name not supplied, valid example MaxShellsPerUser"
    Write-Host "[$scriptName] Exiting with exit code 101"
    exit 101
}

$value = $args[2]
if ($value) {
    Write-Host "[$scriptName] value : $value"
} else {
    Write-Host "[$scriptName] value not supplied, valid example 30"
    Write-Host "[$scriptName] Exiting with exit code 102"
    exit 102
}

Write-Host
# Build the command in a format that is supported in PowerShell
executeExpression "winrm set $URI `'@{$name=`"$value`"}`'"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
