$scriptName = 'Capabilities.ps1'

Write-Host
Write-Host "[$scriptName] ---------- start ----------"

Write-Host
Write-Host "[$scriptName] List the Computer architecture and Service Pack version"
$computer = "."
$sOS =Get-WmiObject -class Win32_OperatingSystem -computername $computer
foreach($sProperty in $sOS) {
	write-host "  Caption                 : $($sProperty.Caption)"
	write-host "  Description             : $($sProperty.Description)"
	write-host "  OSArchitecture          : $($sProperty.OSArchitecture)"
	write-host "  ServicePackMajorVersion : $($sProperty.ServicePackMajorVersion)"
}

Write-Host
Write-Host "[$scriptName] List the PowerShell version"
	write-host "  PSVersion.Major         : $($PSVersionTable.PSVersion.Major)"

Write-Host
Write-Host "[$scriptName] List the .NET Versions (4.5 or higher required)"
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse | Get-ItemProperty -name Version -EA 0 | Where { $_.PSChildName -match '^(?!S)\p{L}'} | Select PSChildName, Version

Write-Host
Write-Host "[$scriptName] List the WIF Installed Versions"
$regkey = 'HKLM:\SOFTWARE\Microsoft\Windows Identity Foundation\setup'
if ( Test-Path $regkey ) { 
	Get-ChildItem $regkey
} else {
	Write-Host
	Write-Host "  Windows Identity Foundation not installed ($regkey)"
}

Write-Host
Write-Host "[$scriptName] List installed MVC products (not applicable after MVC4)"
if (Test-Path 'C:\Program Files (x86)\Microsoft ASP.NET' ) {
	Get-ChildItem 'C:\Program Files (x86)\Microsoft ASP.NET'
} else {
	Write-Host
	Write-Host "  MVC not exmplicitely installed (not required for MVC 5 and above)"
}

Write-Host
Write-Host "[$scriptName] List Web Deploy versions installed"
$regkey = 'HKLM:\Software\Microsoft\IIS Extensions\MSDeploy'
if ( Test-Path $regkey ) { 
	Get-ChildItem $regkey
} else {
	Write-Host
	Write-Host "  Web Deploy not installed ($regkey)"
}

Write-Host
Write-Host "[$scriptName] List the build tools"
$regkey = 'HKLM:\Software\Microsoft\MSBuild\ToolsVersions'
if ( Test-Path $regkey ) { 
	Get-ChildItem $regkey
} else {
	Write-Host
	Write-Host "  Build tools not found ($regkey)"
}

# Pipe seems to stop this from working?
#Write-Host
#Write-Host "[$scriptName] Nuget CLI Version"
#Write-Host
#try { 
#	NuGet.exe | Select-String -Pattern 'NuGet Version'
#} catch {}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
