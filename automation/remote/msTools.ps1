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
	$env:DEV_ENV = (($fileList -match 'devenv.com')[0]).fullname
}

# Search for Visual Studio 2017 and above install first
if (!( $env:MS_BUILD )) {
	$registryKey = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\SxS\VS7'
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

# Try Visual Studio 2015 path
if (!( $env:MS_BUILD )) {
	$msbuild = ((Get-ItemProperty ((Get-Item 'HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions\14.0').pspath) -PSProperty MSBuildToolsPath).MSBuildToolsPath) + 'msbuild.exe'
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
	$env:MS_BUILD = $env:MS_TEST
	Write-Host "`$env:VS_TEST = ${env:VS_TEST}"
}

if ( $env:DEV_ENV ) {
	Write-Host "`$env:DEV_ENV = ${env:DEV_ENV}"
} else {
	Write-Host "Visual Studio devenv not found`n"
}

Write-Host "`n[$scriptName] --- finish---"