$scriptName = 'setDNS.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$ipList = $args[0]
if ($ipList) {
    Write-Host "[$scriptName] ipList : $ipList"
} else {
    Write-Host "[$scriptName] ipList no supplied"
    exit 100
}

Write-Host "[$scriptName] Update and list the interface setttings"
foreach ($item in (Get-DnsClient -InterfaceAlias 'Ethernet*')) {

	Set-DnsClientServerAddress -InterfaceIndex $item.InterfaceIndex -ServerAddresses ($ipList)
	Write-Host "  InterfaceAlias           : $($item.InterfaceAlias)"
	Write-Host "  InterfaceIndex           : $($item.InterfaceIndex)"
	Write-Host "  ConnectionSpecificSuffix : $($item.ConnectionSpecificSuffix)"
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
