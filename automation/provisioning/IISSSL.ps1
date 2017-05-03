Param (
  [string]$thumbPrint,
  [string]$ip,
  [string]$port
)
$scriptName = 'IISSSL.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	$LASTEXITCODE = 0
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if ( $LASTEXITCODE -ne 0 ) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($thumbPrint) {
    Write-Host "[$scriptName] thumbPrint : $thumbPrint"
} else {
    Write-Host "[$scriptName] thumbPrint not passed, exiting with LASTEXITCODE = 53"; exit 53
}
if ($ip) {
    Write-Host "[$scriptName] ip         : $ip"
} else {
	$ip = '0.0.0.0'
    Write-Host "[$scriptName] ip         : $ip (default)"
}
if ($port) {
    Write-Host "[$scriptName] port       : $port"
} else {
	$port = '443'
    Write-Host "[$scriptName] port       : $port (default)"
}
# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $webSite $options `""
}

Write-Host
executeExpression 'import-module WebAdministration'

Write-Host
if (test-path IIS:\SslBindings\$ip!$port) { 
	executeExpression "remove-item IIS:\SslBindings\$ip!$port"
}

$cert = executeExpression "Get-ChildItem -Path Cert:\LocalMachine\My\$thumbPrint"
Write-Host "[$scriptName] New-Item `"IIS:\SslBindings\$ip!$port`" -Value `$cert | Format-Table"
try {
	$value = New-Item "IIS:\SslBindings\$ip!$port" -Value $cert | Format-Table
    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
} catch { echo $_.Exception|format-list -force; exit 2 }
if ( $LASTEXITCODE -ne 0 ) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
$value

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0