$scriptName = 'setStaticIP.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$staticIP = $args[0]
if ($staticIP) {
    Write-Host "[$scriptName] staticIP    : $staticIP"
} else {
    Write-Host "[$scriptName] staticIP not supplied, exiting with exit code 100"
    exit 100
}

foreach ($interface in (Get-DnsClient -InterfaceAlias 'Ethernet*')) {
	if ($staticIP -eq  (Get-NetIPAddress -InterfaceIndex $interface.InterfaceIndex -AddressFamily 'IPv4').IPAddress ) {
	
			$PrefixLength = (Get-NetIPAddress -InterfaceIndex $interface.InterfaceIndex -AddressFamily 'IPv4').PrefixLength
			$InterfaceIndex = (Get-NetIPAddress -InterfaceIndex $interface.InterfaceIndex -AddressFamily 'IPv4').InterfaceIndex 
			Set-NetIPAddress -IPAddress $staticIP -PrefixLength $PrefixLength -InterfaceIndex $InterfaceIndex
			
			# List the setting value
 			Get-NetIPAddress -InterfaceIndex $interface.InterfaceIndex -AddressFamily 'IPv4'
		}
	}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
