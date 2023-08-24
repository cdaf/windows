Param (
	[string]$versionScript
)

$scriptName = 'Capabilities.ps1'

cmd /c "exit 0"
$Error.clear()

function webDeployVersion ( $absPath ) {
	$versionCheck = & $absPath
	$versionCheck = $versionCheck[1].split()[-1]
	$three = '7.1.1973.0'
	if ( [System.Version]$versionCheck -gt [System.Version]$three ) { $versionTest = '4' }
	Write-Host "  Web Deploy              : ${versionTest} ($versionCheck)"
}

if ( ! $versionScript ) {
	Write-Host "`n[$scriptName] ---------- start ----------"
}

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$AUTOMATIONROOT = split-path -parent $scriptPath
if ( Test-Path "$AUTOMATIONROOT\CDAF.windows" ) {
	$check_file = "$AUTOMATIONROOT\CDAF.windows"
} else {
	if ( Test-Path "$CDAF_CORE/CDAF.properties" ) {
		$check_file = "$CDAF_CORE/CDAF.properties"
	}
}
if ( $check_file ) {
	$cdaf_version = (Select-String -Path $check_file -Pattern 'productVersion=').ToString().Split('=')[-1]
} else {
	$cdaf_version = '(cannot determine)' 
}

$browserPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe'
if ( Test-Path $browserPath ) {
	$chromeVersion = ((Get-Item (Get-ItemProperty $browserPath).'(Default)').VersionInfo).ProductVersion
	$versionTest = cmd /c "chromedriver -v 2`>`&1 2>nul"
	if ( $LASTEXITCODE -eq 0 ) {
		$chromeDriverVersion = $versionTest.Split()[1]
	}
}

if ( $versionScript ) {
	if ( $versionScript -eq 'cdaf' ) {
		Write-Output $cdaf_version
		exit 0
	} elseif ( $versionScript -eq 'chrome' ) {
		if ( $chromeVersion ) {
			$chromeVersion = $chromeVersion.Split('.')[0]
			if ( $chromeDriverVersion ) {
				$chromeDriverVersion = $chromeDriverVersion.Split('.')[0] 
			} else {
				$chromeDriverVersion = '0'
			}
			if ( $chromeVersion -eq $chromeDriverVersion) {
				Write-Output $chromeVersion
				exit 0
			} else {
				Write-Output "Chrome version $chromeVersion mismatch Chrome Driver version $chromeDriverVersion"
				exit 6822
			}
		} else {
			Write-Output 'chrome not installed'
			exit 6821
		}
	} else {
		Write-Output "Application check $versionScript not sdupported!"
		exit 6820
	}
}

Write-Host "[$scriptName]   CDAF      : ${cdaf_version}"
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

write-host "  PowerShell              : $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) $($PSVersionTable.PSEdition)"

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

$versionTest = cmd /c dotnet.exe --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  dotnet core             : not installed"
} else {
	$versionLine = $(foreach ($line in $versionTest) { Select-String  -InputObject $line -CaseSensitive "Version  " })
	if ( $versionLine ) {
	$arr = $versionLine -split ':'
		Write-Host "  dotnet core             : $($arr[1])"
	} else {
		Write-Host "  dotnet core             : $versionTest"
	}

	$versionTest = cmd /c livingdoc --version 2`>`&1
	if ( $LASTEXITCODE -eq 0 ) {
		Write-Host "    livingdoc             : $($versionTest[-1])"
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

	$versionTest = cmd /c javac -version 2`>`&1
	if ( $LASTEXITCODE -ne 0 ) {
		Write-Host "    Java Compiler         : not installed"
	} else {
		$array = $versionTest.split(" ")
		if ($array[2]) {
			Write-Host "    Java Compiler         : $($array[2])"
		} else {
			Write-Host "    Java Compiler         : $($array[1])"
		}
	}
	
	$versionTest = @()
	$versionTest += cmd /c ant -version 2`>`&1
	if ( $LASTEXITCODE -ne 0 ) {
		Write-Host "    Apache Ant            : not installed"
	} else {
		$array = $versionTest[-1].split(" ")
		Write-Host "    Apache Ant            : $($array[3])"
	}
	
	$versionTest = cmd /c mvn --version 2`>`&1
	if ( $LASTEXITCODE -ne 0 ) {
		Write-Host "    Apache Maven          : not installed"
	} else {
		$array = $versionTest.split(" ")
		Write-Host "    Apache Maven          : $($array[2])"
	}
}

$versionTest = cmd /c NuGet.exe 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  NuGet                   : not installed"
} else {
	$array = $versionTest.split(" ")
	Write-Host "  NuGet                   : $($array[2])"
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
	Write-Host "  Docker                  : $($array[2].TrimEnd(','))"

	$versionTest = cmd /c docker-compose --version 2`>`&1
	if ( $LASTEXITCODE -ne 0 ) {
		Write-Host "    docker-compose        : not installed"
	} else {
		Write-Host "    docker-compose        : $((($versionTest.Split(',')[0]).Split()[-1]).split('v')[-1])"
	}
}

$versionTest = cmd /c terraform --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  terraform               : not installed"
} else {
	$array = $versionTest.split(" ")
	Write-Host "  terraform               : $($array[1].TrimStart('v'))"
}

$versionTest = cmd /c hugo version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  Hugo                    : not installed"
} else {
	$array = $versionTest.split(" ")
	Write-Host "  Hugo                    : $($array[1].TrimStart('v'))"
}

$versionTest = cmd /c python --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  Python                  : not installed"
} else {
	$array = $versionTest.split(" ")
	Write-Host "  Python                  : $($array[1])"

	$versionTest = cmd /c pip.exe --version 2`>`&1
	if ( $LASTEXITCODE -ne 0 ) {
		Write-Host "    PiP                   : not installed"
	} else {
		$array = $versionTest.split(" ")
		Write-Host "    PiP                   : $($array[1])"
	}
}

$versionTest = cmd /c node --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  NodeJS                  : not installed"
} else {
	Write-Host "  NodeJS                  : $($versionTest.Split('v')[1])"

	$versionTest = cmd /c npm --version 2`>`&1
	if ( $LASTEXITCODE -ne 0 ) {
		Write-Host "    NPM                   : not installed"
	} else {
		Write-Host "    NPM                   : $versionTest"
	}

	$versionTest = cmd /c wrangler -v 2`>`&1
	if ( $LASTEXITCODE -eq 0 ){
		Write-Host "    wrangler              : $versionTest"
	}
	
	$versionTest = cmd /c newman --version 2`>`&1
	if ( $LASTEXITCODE -eq 0 ){
		Write-Host "    newman                : $versionTest"
	}
}

# Kubectl is required for Helm
$versionTest = @()
$versionTest = cmd /c kubectl version --short=true --client=true 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  kubectl                 : not installed"
} else {
	try { $firstLine = $versionTest[0].Split()[0] } catch {
		Write-Host "  kubectl                 : installed but unable to determine from $versionTest"
	}
	if ( $firstLine -ne 'Client' ) {
		try { $secondLine = $versionTest[1].Split('v')[1] } catch {
			Write-Host "  kubectl                 : installed but unable to determine from $versionTest"
		}
	}	
	Write-Host "  kubectl                 : $secondLine"

	$versionTest = cmd /c helm version --short 2`>`&1
	if ( $LASTEXITCODE -ne 0 ) {
		Write-Host "    helm                  : not installed"
	} else {
		$array = $versionTest.split("v")
		Write-Host "    helm                  : $($versionTest.Split('v')[1].Split('+')[0])"
	}
	
	$versionTest = cmd /c helmsman -v 2`>`&1
	if ( $LASTEXITCODE -ne 0 ) {
		Write-Host "    helmsman              : not installed"
	} else {
		$array = $versionTest.split("v")
		Write-Host "    helmsman              : $($versionTest.Split('v')[2])"
	}
}

$versionTest = cmd /c "az version --output tsv 2`>`&1 2>nul"
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  Azure CLI               : not installed"
} else {
	Write-Host "  Azure CLI               : $($versionTest.Split()[0])"

	$versionTest = cmd /c "az extension show --name azure-devops --output tsv 2`>`&1 2>nul"
	if ( $LASTEXITCODE -eq 0 ) {
		Write-Host "    ADO CLI Extension     : $($versionTest.Split()[-1])"
	}
}

try { 
	$msPath = Get-Item -Path 'HKLM:\Software\Microsoft\MSBuild\ToolsVersions\*' -ErrorAction SilentlyContinue
	foreach ( $msbuild in $msPath ) {
		Write-Host "  MS Build                : $($msbuild.Name.Split('\')[-1])"
	}
} catch {
	$versionTest = 'not installed'
}

try { 
	$msPath = Get-Item -Path 'HKLM:\Software\Microsoft\IIS Extensions\MSDeploy\*' -ErrorAction SilentlyContinue
	$versionTest = $msPath[-1].Name.Split('\')[-1] 
	$absPath = & where.exe msdeploy.exe 2>$null
	if ( $LASTEXITCODE -ne 0 ) {
		$absPath = "C:\Program Files (x86)\IIS\Microsoft Web Deploy V${versionTest}\msdeploy.exe"
		try {
			webDeployVersion $absPath
		} catch {
			$absPath = "C:\Program Files\IIS\Microsoft Web Deploy V${versionTest}\msdeploy.exe"
			try {
				webDeployVersion $absPath
			} catch {
				Write-Host "  Web Deploy              : not installed"
			}
		}
	} else {
		webDeployVersion $absPath
	}
} catch {
	Write-Host "  Web Deploy              : not installed"
}

$versionTest = cmd /c vswhere -products * 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "  VSWhere                 : not installed"
} else {
	if ( $versionTest ) { 
		Write-Host "  VSWhere                 : $($versionTest[0].Replace('Visual Studio Locator version ', '')) "

		foreach ( $line in $versionTest ) {
			if ( $line -like '*productId*' ) {
				Write-Host "    Visual Studio Edition : $($line.Split()[-1])"
			}
			if ( $line -like '*catalog_productDisplayVersion*' ) {
				Write-Host "    Visual Studio Version : $($line.Split()[-1])"
			}
		}
		
	} else {
		Write-Host "VSWhere is not returning results, known bug in 4.7.2 Microsoft image https://github.com/microsoft/vswhere/issues/182"
	}
}

if ( $chromeVersion ) {
	Write-Host "  Chrome Browser          : $chromeVersion"

	if ( $chromeDriverVersion ) {
		Write-Host "    Chrome Driver         : $chromeDriverVersion"
	}
}

$browserPath = 'HKCU:\SOFTWARE\Microsoft\Edge\BLBeacon'
if ( Test-Path $browserPath ) {
	$properties = Get-ItemProperty -Path $browserPath
	$edgeVersion = $properties.version
}

if ( ! $edgeVersion ) {
	# Check for container install
	$edgeBinary = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
	if ( Test-Path $edgeBinary ) {
		$FileVersionRaw = (Get-Item $edgeBinary).VersionInfo.FileVersionRaw
		$edgeVersion = "$($FileVersionRaw.Major).$($FileVersionRaw.Minor).$($FileVersionRaw.Build).$($FileVersionRaw.Revision)"
	}
}

if ( $edgeVersion ) {
	Write-Host "  Edge Browser            : $edgeVersion"

	$versionTest = cmd /c "msedgedriver --version 2`>`&1 2>nul"
	if ( $LASTEXITCODE -eq 0 ) {
		Write-Host "    Edge Driver           : $($versionTest.Split()[3])"
	}
}

$browserPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe'
if ( Test-Path $browserPath ) {
	$browserVersionInfo = (Get-Item (Get-ItemProperty $browserPath).'(Default)').VersionInfo
	Write-Host "  FireFox Browser         : $($browserVersionInfo.ProductVersion)"

	$versionTest = cmd /c "geckodriver --version 2`>`&1 2>nul"
	if ( $LASTEXITCODE -eq 0 ) {
		Write-Host "    Gecko Driver          : $($versionTest.Split()[1])"
	}
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
