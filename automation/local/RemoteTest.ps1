$callingPID = $args[0]
$listPSVer = $args[1]

$scriptName = 'RemoteTest.ps1'

Write-Host
Write-Host "[$scriptName] ---------- Start ----------"
Write-Host "[$scriptName] callingPID : $callingPID"
Write-Host "[$scriptName] listPSVer  : $listPSVer"
Write-Host "[$scriptName] pwd        : $(Get-Location)"
Write-Host "[$scriptName] hostname   : $(hostname)"
Write-Host "[$scriptName] whoami     : $(whoami)"
Write-Host
if ($listPSVer) {
	Write-Host "[$scriptName] PSVersionTable details (`$listPSVer set to $listPSVer):"
	$PSVersionTable
} else {
	Write-Host "[$scriptName] Computer architecture and Service Pack version (`$listPSVer not set):"
	$computer = "."
	$sOS =Get-WmiObject -class Win32_OperatingSystem -computername $computer
	foreach($sProperty in $sOS) {
		write-host "  Caption                 : $($sProperty.Caption)"
		write-host "  Description             : $($sProperty.Description)"
		write-host "  OSArchitecture          : $($sProperty.OSArchitecture)"
		write-host "  ServicePackMajorVersion : $($sProperty.ServicePackMajorVersion)"
	}
}
Write-Host
Write-Host "[$scriptName] ---------- Finish ----------"
Write-Host
