Param (
	[string]$ipList,
	[string]$prepend
)

cmd /c "exit 0"
$Error.Clear()

$scriptName = 'setDNS.ps1'
Write-Host "`n[$scriptName] ---------- start ----------"
if ($ipList) {
    Write-Host "[$scriptName] ipList  : $ipList (can pass space or comma separated list, or FQDN)"
} else {
    Write-Host "[$scriptName] ipList no supplied"; exit 100
}

if ($prepend) {
    Write-Host "[$scriptName] prepend : $prepend"
} else {
	Write-Host "[$scriptName] prepend : (net set, will replace)"
}

if (!(($ipList -like '*,*') -or ($ipList -like '* *'))) { 
	$stringTest = $ipList.Split('.')
	$isFQDN = foreach ($item in $stringTest) { if (! ( $item -match "^\d+$" )) { Write-Output $item } }
	if ( $isFQDN ) {
		$ipList = ([System.Net.Dns]::GetHostAddresses($ipList))[0].IPAddressToString
		Write-Host "[$scriptName] Converted from FQDN to $ipList"
	}
}

Write-Host "[$scriptName] DNS List Before"
foreach ($interface in (Get-DnsClient -InterfaceAlias 'Ethernet*')) { (Get-DnsClientServerAddress -InterfaceIndex $interface.InterfaceIndex).ServerAddresses }

Write-Host "[$scriptName] Update and list the interface setttings"
foreach ($interface in (Get-DnsClient -InterfaceAlias 'Ethernet*')) {

	if ($prepend) {
		$ipList = "${ipList},$((Get-DnsClientServerAddress -AddressFamily 'IPv4' -InterfaceIndex $interface.InterfaceIndex).ServerAddresses)"
		Write-Host "[$scriptName] Prepended list $ipList (excludes IPv6)"
	}

	Set-DnsClientServerAddress -InterfaceIndex $interface.InterfaceIndex -ServerAddresses ($ipList)
	Write-Host "  InterfaceAlias           : $($interface.InterfaceAlias)"
	Write-Host "  InterfaceIndex           : $($interface.InterfaceIndex)"
	Write-Host "  ConnectionSpecificSuffix : $($interface.ServerAddresses)"
}

Write-Host "[$scriptName] DNS List After"
foreach ($interface in (Get-DnsClient -InterfaceAlias 'Ethernet*')) { (Get-DnsClientServerAddress -InterfaceIndex $interface.InterfaceIndex).ServerAddresses }

Write-Host "`n[$scriptName] ---------- stop ----------"
