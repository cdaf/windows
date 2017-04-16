
$scriptName = 'trustedHosts.ps1'
Write-Host "`n[$scriptName] ---------- start ----------"
$trustedHosts = $args[0]

# Output File (plain text or XML depending on method) must be supplioed
if ($trustedHosts) {
    Write-Host "[$scriptName] trustedHosts : $trustedHosts"
} else {
    Write-Host "[$scriptName] trustedHosts not passed! Exiting"; exit 100
}
# Provisioning Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $trustedHosts `""
}

Write-Host "`n[$scriptName] Add the trustedHosts ($trustedHosts) as a trusted hosts for Remote Powershell"
Set-WSManInstance -ResourceURI winrm/config/client -ValueSet @{TrustedHosts=$trustedHosts}

Write-Host "`n[$scriptName] ---------- stop -----------`n"
exit 0