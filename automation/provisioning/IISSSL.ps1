Param (
  [string]$thumbPrint,
  [string]$ip,
  [string]$port,
  [string]$siteName
)
$scriptName = 'IISSSL.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
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
if ($siteName) {
    Write-Host "[$scriptName] siteName   : $siteName"
} else {
	$siteName = 'Default Web Site'
    Write-Host "[$scriptName] siteName   : $siteName (default)"
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
if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
$value

if ( $ip -eq '0.0.0.0' ) {
	$ip = '*'
}
$bindCheck = executeExpression "Get-WebBinding -Name '$siteName' -IP $ip -Port $port -Protocol https"
if ( $bindCheck ) { # Observed Windows Container not binding to site, but VM does, generic test for either
	Write-Host "[$scriptName] Binding Exists for $siteName with IP $ip and port $port (Protocol https)"
} else {
	executeExpression "New-WebBinding -Name '$siteName' -IP $ip -Port $port -Protocol https"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0