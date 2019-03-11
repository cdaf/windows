Param (
	[int]$localPort
)

$scriptName = 'nextFreePort.ps1'
cmd /c "exit 0"

# Use the CDAF provisioning helpers
Write-Host "`n[$scriptName] ---------- start ----------"
Write-Host "[$scriptName]   localPort : $localPort`n"

while ($localPort -lt 65535) {
	if ( Get-NetUDPEndpoint | Where LocalPort -eq $localPort ) {
		Write-Host "[$scriptName] $localPort is use for UDP"
		$localPort += 1
	} else {
		if (Get-NetTCPConnection | Where LocalPort -eq $localPort ) {
			Write-Host "[$scriptName] $localPort is use for TCP"
			$localPort += 1
		} else {
			Write-Host "[$scriptName] free port is $localPort"
			Write-Host "`n[$scriptName] ---------- finish ----------"
			return $localPort
		}
		Write-Host "[$scriptName] free port is $localPort"
		Write-Host "`n[$scriptName] ---------- finish ----------"
		return $localPort
	}
}

Write-Host "`n[$scriptName] Failed to find a free port!"
$error.clear()
exit 1