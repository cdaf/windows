$scriptName = 'setDNS.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$ipList = $args[0]
if ($ipList) {
    Write-Host "[$scriptName] ipList : $ipList"
} else {
    Write-Host "[$scriptName] ipList no supplied"; exit 100
}
# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $ipList`""
}

Write-Host "[$scriptName] Update and list the interface setttings"
foreach ($interface in (Get-DnsClient -InterfaceAlias 'Ethernet*')) {

	Set-DnsClientServerAddress -InterfaceIndex $interface.InterfaceIndex -ServerAddresses ($ipList)
	Write-Host "  InterfaceAlias           : $($interface.InterfaceAlias)"
	Write-Host "  InterfaceIndex           : $($interface.InterfaceIndex)"
	Write-Host "  ConnectionSpecificSuffix : $($interface.ServerAddresses)"
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
