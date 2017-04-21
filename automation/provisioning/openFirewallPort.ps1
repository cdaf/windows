function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
}

$scriptName = 'openFirewallPort.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$portNumber = $args[0]
if ($portNumber) {
    Write-Host "[$scriptName] portNumber  : $portNumber"
} else {
    Write-Host "[$scriptName] portNumber not supplied, exiting with code 100"
    exit 100
}

$displayName = $args[1]
if ($displayName) {
    Write-Host "[$scriptName] displayName : $displayName"
} else {
	$displayName = $portNumber
    Write-Host "[$scriptName] displayName : not supplied, default to Port Number ($displayName)"
}
# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $portNumber $displayName `""
}

executeExpression "New-NetFirewallRule -DisplayName `"$displayName`" -Direction Inbound –Protocol TCP –LocalPort $portNumber -Action allow"

Write-Host
Write-Host "[$scriptName] Created $portNumber on $dbhost\$dbinstance at $createdDate."

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
