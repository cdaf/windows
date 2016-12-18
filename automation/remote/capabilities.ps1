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
Write-Host "[$scriptName] List the Computer architecture, Service Pack and 3rd party software"
Write-Host
$computer = "."
$sOS =Get-WmiObject -class Win32_OperatingSystem -computername $computer
foreach($sProperty in $sOS) {
	write-host "  Caption                 : $($sProperty.Caption)"
	write-host "  Description             : $($sProperty.Description)"
	write-host "  OSArchitecture          : $($sProperty.OSArchitecture)"
	write-host "  ServicePackMajorVersion : $($sProperty.ServicePackMajorVersion)"
}

$EditionId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'EditionID').EditionId
if (($EditionId -like "*nano*") -or ($EditionId -like "*core*") ) {
	$noGUI = '(no GUI)'
}
write-host "  EditionId               : $EditionId $noGUI"
write-host "  PSVersion.Major         : $($PSVersionTable.PSVersion.Major)"

$javaVersion = cmd /c java -version 2`>`&1
if ($javaVersion -like '*not recognized*') {
	Write-Host "  Java                    : not installed"
} else {
	$array = $javaVersion.split(" ")
	Write-Host "  Java                    : $($array[2])"
}

$javaCompiler = cmd /c javac -version 2`>`&1
if ($javaCompiler -like '*not recognized*') {
	Write-Host "  Java Compiler           : not installed"
} else {
	$array = $javaCompiler.split(" ")
	Write-Host "  Java Compiler           : $($array[2])"
}

$mavenVersion = cmd /c mvn --version 2`>`&1
if ($mavenVersion -like '*not recognized*') {
	Write-Host "  Maven                   : not installed"
} else {
	$array = $mavenVersion.split(" ")
	Write-Host "  Maven                   : $($array[2])"
}

$nugetVersion = cmd /c NuGet 2`>`&1
if ($mavenVersion -like '*not recognized*') {
	Write-Host "  NuGet                   : not installed"
} else {
	$array = $nugetVersion.split(" ")
	Write-Host "  NuGet                   : $($array[2])"
}

$zipVersion = cmd /c 7za.exe i 2`>`&1
if ($zipVersion -like '*not recognized*') {
	Write-Host "  7za.exe                 : not installed"
} else {
	$array = $zipVersion.split(" ")
	Write-Host "  7za.exe                 : $($array[3])"
}

$curlVersion = cmd /c curl.exe --version 2`>`&1
if ($curlVersion -like '*not recognized*') {
	Write-Host "  curl.exe                : not installed"
} else {
	$array = $curlVersion.split(" ")
	Write-Host "  curl.exe                : $($array[1])"
}

Write-Host
Write-Host "[$scriptName] List the build tools"
$regkey = 'HKLM:\Software\Microsoft\MSBuild\ToolsVersions'
Write-Host
if ( Test-Path $regkey ) { 
	foreach($buildTool in Get-ChildItem $regkey) {
		Write-Host "  $buildTool"
	}
} else {
	Write-Host "  Build tools not found ($regkey)"
}

Write-Host
Write-Host "[$scriptName] List the WIF Installed Versions"
$regkey = 'HKLM:\SOFTWARE\Microsoft\Windows Identity Foundation\setup'
Write-Host
if ( Test-Path $regkey ) { 
	foreach($wif in Get-ChildItem $regkey) {
		Write-Host "  $wif"
	}
} else {
	Write-Host "  Windows Identity Foundation not installed ($regkey)"
}

Write-Host
Write-Host "[$scriptName] List installed MVC products (not applicable after MVC4)"
Write-Host
if (Test-Path 'C:\Program Files (x86)\Microsoft ASP.NET' ) {
	foreach($mvc in Get-ChildItem 'C:\Program Files (x86)\Microsoft ASP.NET') {
		Write-Host "  $mvc"
	}
} else {
	Write-Host "  MVC not explicitely installed (not required for MVC 5 and above)"
}

Write-Host
Write-Host "[$scriptName] List Web Deploy versions installed"
Write-Host
$regkey = 'HKLM:\Software\Microsoft\IIS Extensions\MSDeploy'
if ( Test-Path $regkey ) { 
	foreach($msDeploy in Get-ChildItem $regkey) {
		Write-Host "  $msDeploy"
	}
} else {
	Write-Host "  Web Deploy not installed ($regkey)"
}

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

$error.clear()
exit 0
