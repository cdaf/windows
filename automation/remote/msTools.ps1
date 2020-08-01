Param (
	[string]$msTestOnly
)

cmd /c "exit 0"
$scriptName = 'msTools.ps1'

Write-Host "`n[$scriptName] --- start ---`n"
Write-Host "[$scriptName] Current `$env:MS_BUILD   : $env:MS_BUILD"
$env:MS_BUILD = $nul
Write-Host "[$scriptName] Current `$env:MS_TEST    : $env:MS_TEST"
$env:MS_TEST = $nul
Write-Host "[$scriptName] Current `$env:VS_TEST    : $env:VS_TEST"
$env:VS_TEST = $nul
Write-Host "[$scriptName] Current `$env:DEV_ENV    : $env:DEV_ENV"
$env:DEV_ENV = $nul
Write-Host "[$scriptName] Current `$env:NUGET_PATH : $env:NUGET_PATH"
$env:NUGET_PATH = $nul
$versionTest = cmd /c vswhere 2`>`&1
if ($versionTest -like '*not recognized*') {
	Write-Host "[$scriptName] VSWhere                 : not installed"
} else {
	if ( $versionTest ) {
		Write-Host "[$scriptName] VSWhere                 : $($versionTest[0].Replace('Visual Studio Locator version ', ''))"
		$obj = vswhere -latest -products * -format json | ConvertFrom-Json
		if ( $obj ) {
			Write-Host "[$scriptName] Latest Visual Studio install is $($obj.displayName)"
			$env:DEV_ENV = $obj.productPath
			
			$env:MS_BUILD = vswhere -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe
			if (!( $env:MS_BUILD )) {
				$tempObj = Get-ChildItem $obj.installationPath -Recurse -Filter 'msbuild.exe'
				if ( $tempObj ) {
					$env:MS_BUILD = $tempObj[0].FullName
				}
			}
			$testPath = vswhere -latest -products * -requires Microsoft.VisualStudio.Workload.ManagedDesktop Microsoft.VisualStudio.Workload.Web -requiresAny -property installationPath
			if ( $testPath ) {
				$env:VS_TEST = join-path $testPath 'Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe'
			}
			if (!( $env:VS_TEST )) {
				$tempObj = Get-ChildItem $obj.installationPath -Recurse -Filter 'vstest.console.exe'
				if ( $tempObj ) {
					$env:VS_TEST = $tempObj[0].FullName
				}
			}
			$tempObj = Get-ChildItem $obj.installationPath -Recurse -Filter 'mstest.exe'
			if ( $tempObj ) {
				$env:MS_TEST = $tempObj[0].FullName
			}
		}
	} else {
		Write-Host "`n[$scriptName] VSWhere installed, but not returning an data, fall back to legacy detection..."
	}
}

if (!( $env:MS_BUILD )) {
	$registryKey = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\SxS\VS7'
	if ( Test-Path $registryKey ) {
		Write-Host "`n[$scriptName] Search for tools in Visual Studio 2017 and above install first"
		$list = Get-ItemProperty $registryKey | Get-Member
		$installs = @()
		foreach ($element in $list) { if ($element -match '.0') { $installs += $element.Definition.Split('=')[1] }}
		$versionTest = $installs[-1] # use latest version of Visual Studio
		if ( $versionTest ) {
			$fileList = @(Get-ChildItem $versionTest -Recurse)
			$env:MS_BUILD = (($fileList -match 'msbuild.exe')[0]).fullname
			$env:MS_TEST = (($fileList -match 'mstest.exe')[0]).fullname
			$env:VS_TEST = (($fileList -match 'vstest.exe')[0]).fullname
			$env:DEV_ENV = (($fileList -match 'devenv.com')[0]).fullname
		}
	}
}

if (! ($env:MS_BUILD) ) {
	Write-Host "`n[$scriptName] MSBuild not found, search common Visual Studio paths ..."
	$testlookup = Get-ChildItem -Recurse "C:\Program Files (x86)\Microsoft Visual Studio" -Filter "MSBuild.exe"
	if ( $testlookup ) {
		$env:MS_BUILD = $testlookup[-1].FullName
	}
}

if (!( $env:MS_BUILD )) {
	Write-Host "`n[$scriptName] ... MSBuild not found, try Visual Studio 2017 path ..."
	$registryKey = 'HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions\14.0'
	if ( Test-Path $registryKey ) {
		$env:MS_BUILD = ((Get-ItemProperty ((Get-Item $registryKey).pspath) -PSProperty MSBuildToolsPath).MSBuildToolsPath) + 'msbuild.exe'
	}
}

if (! ($env:MS_TEST) ) {
	Write-Host "`n[$scriptName] MSTest not found, search for VSTS agent install ..."
	$testlookup = Get-ChildItem -Recurse "C:\Program Files (x86)\Microsoft Visual Studio" -Filter "MSTest.exe"
	if ( $testlookup ) {
		$env:MS_TEST = $testlookup[0].FullName
	}
}

if (! ($env:MS_TEST) ) {
	Write-Host "`n[$scriptName] ... MSTest not found, try Visual Studio 2017 path ..."
	$registryKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\196D6C5077EC79D56863FE52B7080EF6'
	if ( Test-Path $registryKey ) {
		$env:MS_TEST = (Get-ItemProperty ((Get-Item $registryKey).pspath)).'06F460ED2256013369565B3E7EB86383'
	}
}

if (! ($env:MS_TEST) ) {
	Write-Host "`n[$scriptName] ... MSTest not found, try Visual Studio 2015 path ..."
	$registryKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\196D6C5077EC79D56863FE52B7080EF6'
	if ( Test-Path $registryKey ) {
		$env:MS_TEST = (Get-ItemProperty ((Get-Item $registryKey).pspath)).'4EEF88CE629328E30A83748F4CABD953'
	}
}

if (! ($env:VS_TEST) ) {
	Write-Host "`n[$scriptName] VS test console not found, search for VSTS agent install ..."
	$testlookup = Get-ChildItem -Recurse "C:\Program Files (x86)\Microsoft Visual Studio" -Filter "vstest.console.exe"
	if ( $testlookup ) {
		$env:VS_TEST = $testlookup[0].FullName
	}
}

$versionTest = cmd /c NuGet 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	cmd /c "exit 0"
	executeExpression "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls11,Tls12'"
	$versionTest = cmd /c .\nuget.exe 2`>`&1
	$env:NUGET_PATH = '.\nuget.exe'
} else {
	$nugetPaths = (cmd /c "where.exe NuGet").Split([string[]]"`r`n",'None')
	$env:NUGET_PATH = $nugetPaths[0]
	if ( $nugetPaths.Count -gt 1 ) {
		Write-Host "Using first match only for NuGet path = ${env:NUGET_PATH}. Unused paths:"
		for ( $i = 1; $i -lt $nugetPaths.Count ; $i++ ) {
			Write-Host "   $($nugetPaths[$i])"
		}
	}
}
$array = $versionTest.split(" ")
Write-Host "`n`$env:NUGET_PATH = ${env:NUGET_PATH} (version $($array[2]))"

if ( $env:MS_BUILD ) {
	Write-Host "`$env:MS_BUILD = ${env:MS_BUILD}"
} else {
	Write-Host "MSBuild not found!`n"
	exit 4700
}

if ( $env:MS_TEST ) {
	Write-Host "`$env:MS_TEST = ${env:MS_TEST}"
} else {
	Write-Host "MSTest not found"
}

if ( $env:VS_TEST ) {
	Write-Host "`$env:VS_TEST = ${env:VS_TEST}"
} else {
	Write-Host "VSTest not found, defaulting to `$env:MS_TEST"
	$env:VS_TEST = $env:MS_TEST
	Write-Host "`$env:VS_TEST = ${env:VS_TEST}"
}

if ( $env:DEV_ENV ) {
	Write-Host "`$env:DEV_ENV = ${env:DEV_ENV}"
} else {
	Write-Host "Visual Studio devenv not found`n"
}

Write-Host "`n[$scriptName] --- finish---"