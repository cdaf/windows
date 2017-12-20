Param (
	[string]$msTestOnly
)
if(! ($msTestOnly) ){
	Write-Host "Retrieve MSBuild path`n"
	$env:MS_BUILD = ((Get-ItemProperty ((Get-Item 'HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions\14.0').pspath) -PSProperty MSBuildToolsPath).MSBuildToolsPath) + 'msbuild.exe'
	if (! ($env:MS_BUILD) ) { 
		Write-Host "MSBuild tool folder not found in registry at HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions\14.0 `n"
		exit 4700
	}
	if (! (test-path $env:MS_BUILD) ) {
		Write-Host "MSBuild not found!`n"
		exit 4701
	}
}
Write-Host "Try to retrieve MSTest path from registry`n"
try {
	$env:MS_TEST = (Get-ItemProperty ((Get-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\196D6C5077EC79D56863FE52B7080EF6').pspath)).'06F460ED2256013369565B3E7EB86383'
	if (! ($env:MS_TEST) ) {
		$env:MS_TEST = (Get-ItemProperty ((Get-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\196D6C5077EC79D56863FE52B7080EF6').pspath)).'4EEF88CE629328E30A83748F4CABD953'
	}
} catch {
	# Ignore lookup exception and proceed
}

if (! ($env:MS_TEST) ) {
	Write-Host "Try to retrieve MSTest path from Visual Studio 2015`n"
	if ( Test-Path 'C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\MSTest.exe' ) {
		$env:MS_TEST = 'C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\MSTest.exe'
	}
}

if (! ($env:MS_TEST) ) {
	Write-Host "Try to retrieve MSTest path from Visual Studio 2017`n"
	if ( Test-Path 'C:/Program Files (x86)/Microsoft Visual Studio/2017/Enterprise/Common7/IDE/MSTest.exe' ) {
		$env:MS_TEST = 'C:/Program Files (x86)/Microsoft Visual Studio/2017/Enterprise/Common7/IDE/MSTest.exe'
	}
}
if (! ($env:MS_TEST) ) {
	Write-Host "MSTest not found`n"
	exit 4703
}
