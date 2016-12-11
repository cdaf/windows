$scriptName = 'Capabilities.ps1'

Write-Host
Write-Host "[$scriptName] ---------- start ----------"

Write-Host
Write-Host "[$scriptName] List networking"
Write-Host "[$scriptName]   Hostname : $(hostname)"
foreach ($item in Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName .) {
	Write-Host "[$scriptName]         IP : $($item.IPAddress)"
}

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
Write-Host "[$scriptName] List the .NET Versions"
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse |
Get-ItemProperty -name Version,Release -EA 0 |
Where { $_.PSChildName -match '^(?!S)\p{L}'} |
Select PSChildName, Version, Release, @{
  name="Product"
  expression={
      switch -regex ($_.Release) {
        "378389" { [Version]"4.5" }
        "378675|378758" { [Version]"4.5.1" }
        "379893" { [Version]"4.5.2" }
        "393295|393297" { [Version]"4.6" }
        "394254|394271" { [Version]"4.6.1" }
        "394802|394806" { [Version]"4.6.2" }
        {$_ -gt 394806} { [Version]"Undocumented 4.6.2 or higher, please update script" }
      }
    }
}

Write-Host
Write-Host "[$scriptName] List the build tools (HKLM:\Software\Microsoft\MSBuild\ToolsVersions)"
$regkey = 'HKLM:\Software\Microsoft\MSBuild\ToolsVersions'
if ( Test-Path $regkey ) { 
	Get-ChildItem $regkey
} else {
	Write-Host
	Write-Host "  Build tools not found ($regkey)"
}

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
	Write-Host "  MVC not explicitely installed (not required for MVC 5 and above)"
}

Write-Host
Write-Host "[$scriptName] List Web Deploy versions installed"
$regkey = 'HKLM:\Software\Microsoft\IIS Extensions\MSDeploy'
if ( Test-Path $regkey ) { 
	Get-ChildItem $regkey
} else {
	Write-Host "  Web Deploy not installed ($regkey)"
}

Write-Host
$javaVersion = cmd /c java -version 2`>`&1
$javaVersion = $javaVersion | Select-String -Pattern 'ersion'
if ( $javaVersion ) { 
	Write-Host "[$scriptName] $javaVersion"
} else {
	Write-Host "[$scriptName] Java not installed"
}

$javaVersion = cmd /c javac -version 2`>`&1
if ($javaVersion -like '*not recognized*') {
	Write-Host "[$scriptName] Java Compiler not installed"
} else {
	Write-Host "[$scriptName] Java Compiler : $javaVersion"
}

$mavenVersion = cmd /c mvn --version 2`>`&1
$mavenVersion = $mavenVersion | Select-String -Pattern 'ersion'
if ( $mavenVersion ) { 
	Write-Host "[$scriptName] Maven Version : $mavenVersion"
} else {
	Write-Host "[$scriptName] Maven builder not installed"
}

$nugetVersion = cmd /c NuGet 2`>`&1
$nugetVersion = $nugetVersion | Select-String -Pattern 'ersion'
if ( $nugetVersion ) { 
	$nugetVersion = "$nugetVersion "
	$nugetVersion = $nugetVersion -split 'update'
	Write-Host "[$scriptName] $($nugetVersion[0])"
} else {
	Write-Host "[$scriptName] NuGet not installed"
}

$zipVersion = cmd /c 7za.exe i 2`>`&1
$zipVersion = $zipVersion | Select-String -Pattern '7-Zip'
if ( $zipVersion ) { 
	Write-Host "[$scriptName] $zipVersion"
} else {
	Write-Host "[$scriptName] 7Zip Command line not installed"
}

$curlVersion = cmd /c curl.exe --version 2`>`&1
$curlVersion = $curlVersion | Select-String -Pattern 'libcurl'
if ( $curlVersion ) { 
	Write-Host "[$scriptName] $curlVersion"
} else {
	Write-Host "[$scriptName] curl.exe not installed"
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
$error.clear()
exit 0
