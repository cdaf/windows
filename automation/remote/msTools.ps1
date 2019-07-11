Param (
	[string]$msTestOnly
)

cmd /c "exit 0"
$scriptName = 'msTools.ps1'

Write-Host "`n[$scriptName] --- start ---`n"

# First try to use vswhere
$versionTest = cmd /c vswhere -products * 2`>`&1
if ($versionTest -like '*not recognized*') {
	Write-Host "VSWhere : not installed"
} else {
	Write-Host "VSWhere : $($versionTest[0].Replace('Visual Studio Locator version ', ''))"
	$pathAttribute = 'installationPath: '
	$fileList = @(Get-ChildItem $(($versionTest -match $pathAttribute).replace($pathAttribute, '')) -Recurse)
	$env:MS_BUILD = (($fileList -match 'msbuild.exe')[0]).FullName
	$env:MS_TEST = (($fileList -match 'mstest.exe')[0]).FullName
	$env:VS_TEST = (($fileList -match 'vstest.exe')[0]).FullName
}

# Search for Visual Studio install fist
if (!( $env:MS_BUILD )) {
	if ( Test-Path 'C:\Program Files (x86)\Microsoft Visual Studio' ) {
		foreach ( $version in Get-ChildItem 'C:\Program Files (x86)\Microsoft Visual Studio\20*\*' ) {
			if ( Test-Path "${version}\Common7\IDE\MSTest.exe" ) {
				$env:MS_TEST = "${version}\Common7\IDE\MSTest.exe"
			}
		}
		
		foreach ( $version in Get-ChildItem 'C:\Program Files (x86)\Microsoft Visual Studio\20*\*\MSBuild\*\bin' ) {
			if ( Test-Path "${version}\MSBuild.exe" ) {
				$env:MS_BUILD = "${version}\MSBuild.exe"
			}
		}
	}
}

# Then search OS install
if (!( $env:MS_BUILD )) {
	$registryKey = 'HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions\'
	foreach ($version in Get-ChildItem $registryKey) { 
		$integer = [int][io.path]::GetFileNameWithoutExtension($version)
		if ( $previous ) {
			if ( $previous -gt $integer ) {
				$integer = $previous
			}
		}
		$previous = $integer
	}
	$registryKey = $registryKey + $integer + '.0'
	$env:MS_BUILD = ((Get-ItemProperty ((Get-Item $registryKey).pspath) -PSProperty MSBuildToolsPath).MSBuildToolsPath) + 'msbuild.exe'
}

if ( $env:MS_BUILD ) {
	Write-Host "`$env:MS_BUILD = ${env:MS_BUILD}"
} else {
	Write-Host "MSBuild not found!`n"
	exit 4700
}

# Visual Studio 2015 has a different path to latest
if (! ($env:MS_TEST) ) {
	if ( Test-Path 'C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\MSTest.exe' ) {
		$env:MS_TEST = 'C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\MSTest.exe'
	}
}

# Finally search for VSTS agent install
if (! ($env:MS_TEST) ) {
	$reg = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\196D6C5077EC79D56863FE52B7080EF6'
	if ( Test-Path $reg ) {
		$env:MS_TEST = (Get-ItemProperty ((Get-Item $reg).pspath)).'06F460ED2256013369565B3E7EB86383'
	}
}

if (! ($env:MS_TEST) ) {
	$reg = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\196D6C5077EC79D56863FE52B7080EF6'
	if ( Test-Path $reg ) {
		$env:MS_TEST = (Get-ItemProperty ((Get-Item $reg).pspath)).'4EEF88CE629328E30A83748F4CABD953'
	}
}

if ( $env:MS_TEST ) {
	Write-Host "`$env:MS_TEST = ${env:MS_TEST}"
} else {
	Write-Host "MSTest not found`n"
}

$versionTest = cmd /c NuGet 2`>`&1
if ($versionTest -like '*not recognized*') {
	(New-Object System.Net.WebClient).DownloadFile('https://dist.nuget.org/win-x86-commandline/latest/nuget.exe', "$PWD\nuget.exe")
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
Write-Host "`$env:NUGET_PATH = ${env:NUGET_PATH} (version $($array[2]))"

Write-Host "`n[$scriptName] --- finish---"