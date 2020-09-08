$scriptName = 'Capabilities.ps1'

Write-Host "`n[$scriptName] ---------- start ----------"

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$AUTOMATIONROOT = split-path -parent $scriptPath
if ( Test-Path "$AUTOMATIONROOT\CDAF.windows" ) {
	Write-Host "[$scriptName]   CDAF      : $((Select-String -Path "$AUTOMATIONROOT\CDAF.windows" -Pattern 'productVersion=').ToString().Split('=')[-1])"
}

Write-Host "[$scriptName]   hostname  : $(hostname)"
Write-Host "[$scriptName]   pwd       : $(Get-Location)"
Write-Host "[$scriptName]   whoami    : $(whoami)" 

Write-Host "`n[$scriptName] List networking"
if ((Get-WmiObject win32_computersystem).partofdomain -eq $true) {
	Write-Host "[$scriptName]   Domain    : $((Get-WmiObject win32_computersystem).domain)"
} else {
	Write-Host "[$scriptName]   Workgroup : $((Get-WmiObject win32_computersystem).domain)"
}

foreach ($item in Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName .) {
	Write-Host "[$scriptName]          IP : $($item.IPAddress)"
}

Write-Host "`n[$scriptName] Computer OS & Architecture`n"
write-host "  Version                 : $([Environment]::OSVersion.VersionString)"
$ReleaseId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'ReleaseId').ReleaseId
write-host "  ReleaseId               : $ReleaseId"
$EditionId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'EditionID').EditionId
write-host "  EditionId               : $EditionId"
$CurrentBuild = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'CurrentBuild').CurrentBuild
write-host "  CurrentBuild            : $CurrentBuild"

$computer = "."
$sOS =Get-WmiObject -class Win32_OperatingSystem -computername $computer
foreach($sProperty in $sOS) {
	write-host "  Caption                 : $($sProperty.Caption)"
	write-host "  OSArchitecture          : $($sProperty.OSArchitecture)"
	write-host "  ServicePackMajorVersion : $($sProperty.ServicePackMajorVersion)"
}

write-host "  PowerShell              : $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"

#Write-Host "`n[$scriptName] List the enabled roles`n"
#$tempFile = "$env:temp\tempName.log"
#& dism.exe /online /get-features /format:table | out-file $tempFile -Force      
#$WinFeatures = $((Import-CSV -Delim '|' -Path $tempFile -Header Name,state | Where-Object {$_.State -eq "Enabled "}) | Select Name)
#Write-Host "$WinFeatures"
#Remove-Item -Path $tempFile 

if ( Test-Path "C:\windows-master\automation\CDAF.windows" ) {
	$nameValue = $(Get-Content "C:\windows-master\automation\CDAF.windows" | findstr "productVersion")
	$name, $value = $nameValue -split '=', 2
	write-host "  CDAF in-box Version     : $value"
}

Write-Host "`n[$scriptName] List 3rd party components`n"
$versionTest = cmd /c git --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  Git                     : not installed"
} else {
	$array = $versionTest.split(" ")
	Write-Host "  Git                     : $($array[2])"
}

$versionTest = cmd /c dotnet --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  dotnet core             : not installed"
} else {
	$versionLine = $(foreach ($line in dotnet) { Select-String  -InputObject $line -CaseSensitive "Version  " })
	if ( $versionLine ) {
	$arr = $versionLine -split ':'
		Write-Host "  dotnet core             : $($arr[1])"
	} else {
		Write-Host "  dotnet core             : $versionTest"
	}
}

$versionTest = cmd /c choco --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  Chocolatey              : not installed"
} else {
	Write-Host "  Chocolatey              : $versionTest"
}

$versionTest = cmd /c java -version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  Java                    : not installed"
} else {
	$array = $versionTest.split(" ")
	$array = $array[2].split('"')
	Write-Host "  Java                    : $($array[1])"
}

$versionTest = cmd /c javac -version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  Java Compiler           : not installed"
} else {
	$array = $versionTest.split(" ")
	if ($array[2]) {
		Write-Host "  Java Compiler           : $($array[2])"
	} else {
		Write-Host "  Java Compiler           : $($array[1])"
	}
}

$versionTest = cmd /c ant -version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  Apache Ant              : not installed"
} else {
	$array = $versionTest.split(" ")
	Write-Host "  Apache Ant              : $($array[3])"
}

$versionTest = cmd /c mvn --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  Apache Maven            : not installed"
} else {
	$array = $versionTest.split(" ")
	Write-Host "  Apache Maven            : $($array[2])"
}

$versionTest = cmd /c NuGet 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  NuGet                   : not installed"
} else {
	$array = $versionTest.split(" ")
	Write-Host "  NuGet                   : $($array[2])"
}

$versionTest = cmd /c 7za.exe i 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  7za.exe                 : not installed"
} else {
	$array = $versionTest.split(" ")
	Write-Host "  7za.exe                 : $($array[3])"
}

$versionTest = cmd /c curl.exe --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  curl.exe                : not installed"
} else {
	$array = $versionTest.split(" ")
	Write-Host "  curl.exe                : $($array[1])"
}

$versionTest = cmd /c tar --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  tar                     : not installed"
} else {
	$array = $versionTest.split(" ")
	Write-Host "  tar                     : $($array[1]) $($array[2]) $($array[3])"
}

$versionTest = cmd /c docker --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  Docker                  : not installed"
} else {
	$array = $versionTest.split(" ")
	Write-Host "  Docker                  : $($array[2])"
}

$versionTest = cmd /c python --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  Python                  : not installed"
} else {
	$array = $versionTest.split(" ")
	Write-Host "  Python                  : $($array[1])"
}

$versionTest = cmd /c pip.exe --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  PiP                     : not installed"
} else {
	$array = $versionTest.split(" ")
	Write-Host "  PiP                     : $($array[1])"
}

$versionTest = cmd /c node --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  NodeJS                  : not installed"
} else {
	Write-Host "  NodeJS                  : $versionTest"
}

$versionTest = cmd /c npm --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  NPM                     : not installed"
} else {
	Write-Host "  NPM                     : $versionTest"
}

$versionTest = cmd /c vswhere -products * 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  VSWhere                 : not installed"
} else {
	if ( $versionTest ) { 
		Write-Host "  VSWhere                 : $($versionTest[0].Replace('Visual Studio Locator version ', '')) "
		Write-Host "`n[$scriptName] List the build tools`n"
		$regkey = 'HKLM:\Software\Microsoft\MSBuild\ToolsVersions'
		if (!($versionTest -like '*not recognized*') ) {
			foreach ($line in $versionTest) {
				if ( $line -like '*productId*' ) {
					Write-Host "  $($line.replace('productId: ', ''))"
				}
			}
		}
		if ( Test-Path $regkey ) { 
			foreach($buildTool in Get-ChildItem $regkey) {
				Write-Host "  $buildTool"
			}
		} else {
			Write-Host "  Build tools not found ($regkey)"
		}
	} else {
		Write-Host "VSWhere is not returning results, known bug in 4.7.2 Microsoft image https://github.com/microsoft/vswhere/issues/182"
	}
}

Write-Host "`n[$scriptName] List the WIF Installed Versions`n"
$regkey = 'HKLM:\SOFTWARE\Microsoft\Windows Identity Foundation\setup'
if ( Test-Path $regkey ) { 
	foreach($wif in Get-ChildItem $regkey) {
		Write-Host "  $wif"
	}
} else {
	Write-Host "  Windows Identity Foundation not installed ($regkey)"
}

Write-Host "`n[$scriptName] List installed MVC products (not applicable after MVC4)`n"
if (Test-Path 'C:\Program Files (x86)\Microsoft ASP.NET' ) {
	foreach($mvc in Get-ChildItem 'C:\Program Files (x86)\Microsoft ASP.NET') {
		Write-Host "  $mvc"
	}
} else {
	Write-Host "  MVC not explicitely installed (not required for MVC 5 and above)"
}

Write-Host "`n[$scriptName] List Web Deploy versions installed`n"
$regkey = 'HKLM:\Software\Microsoft\IIS Extensions\MSDeploy'
if ( Test-Path $regkey ) { 
	foreach($msDeploy in Get-ChildItem $regkey) {
		Write-Host "  $msDeploy"
	}
} else {
	Write-Host "  Web Deploy not installed ($regkey)"
}

Write-Host "`n[$scriptName] List the .NET Versions"
$job = Start-Job {
	$dotnet = $(
		Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse |
		Get-ItemProperty -name Version,Release -EA 0 |
		Where-Object { $_.PSChildName -match '^(?!S)\p{L}'} |
		Select-Object PSChildName, Version, Release, @{
		  name="Product"
		  expression={
		    switch -regex ($_.Release) {
		      "378389" { [Version]"4.5" }
		      "378675|378758" { [Version]"4.5.1" }
		      "379893" { [Version]"4.5.2" }
		      "393295|393297" { [Version]"4.6" }
		      "394254|394271" { [Version]"4.6.1" }
		      "394802|394806" { [Version]"4.6.2" }
		      "460798|460805" { [Version]"4.7" }
		      "461308|461310" { [Version]"4.7.1" }
		      "461808|461814" { [Version]"4.7.2" }
		      "528040|528049" { [Version]"4.8" }
		      {$_ -gt 528049} { [Version]"Undocumented 4.8.x or higher, please update script" }
		    }
		  }
		}
	)
	$dotnet | Format-Table
} | Wait-Job
Receive-Job $job

Write-Host "[$scriptName] List C++ Versions`n"
$job = Start-Job {
	if ( Test-Path 'HKLM:\SOFTWARE\Classes\Installer\Dependencies' ) {
		foreach ($installed in Get-childItem 'HKLM:\SOFTWARE\Classes\Installer\Dependencies\') {
			if ($installed.ToString() -match 'VC_' ) {
				(Get-ItemProperty $installed.PSPath -Name DisplayName ).DisplayName
			}
		}
	} else {
		Write-Host "`n[Capabilities.ps1] HKLM:\SOFTWARE\Classes\Installer\Dependencies not found"
	}
} | Wait-Job
Receive-Job $job

Write-Host "`n[$scriptName] ---------- finish ----------`n"
cmd /c "exit 0"
$error.clear()
exit 0
