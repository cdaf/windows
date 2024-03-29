Param (
	[string]$msTestOnly
)

cmd /c "exit 0"
$scriptName = 'msTools.ps1'

Write-Host "`n[$scriptName] --- start ---"
if ( $env:MS_BUILD ) {
	Write-Host "[$scriptName] Current `$env:MS_BUILD   : $env:MS_BUILD"
	$env:MS_BUILD = $nul
}

if ( $env:MS_TEST ) {
	Write-Host "[$scriptName] Current `$env:MS_TEST    : $env:MS_TEST"
	$env:MS_TEST = $nul
}

if ( $env:VS_TEST ) {
	Write-Host "[$scriptName] Current `$env:VS_TEST    : $env:VS_TEST"
	$env:VS_TEST = $nul
}

if ( $env:DEV_ENV ) {
	Write-Host "[$scriptName] Current `$env:DEV_ENV    : $env:DEV_ENV"
	$env:DEV_ENV = $nul
}

if ( $env:NUGET_PATH ) {
	Write-Host "[$scriptName] Current `$env:NUGET_PATH : $env:NUGET_PATH"
	$env:NUGET_PATH = $nul
}

$vstestContext = 'Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe'
$mstestContext = 'Common7\IDE\MSTest.exe'

$versionTest = cmd /c vswhere 2`>`&1
if ($versionTest -like '*not recognized*') {
	Write-Host "[$scriptName] VSWhere                 : not installed`n"
} else {
	if ( $versionTest ) {
		Write-Host "[$scriptName] VSWhere                 : $($versionTest[0].Replace('Visual Studio Locator version ', ''))`n"
		$obj = vswhere -latest -products * -format json | ConvertFrom-Json
		if ( $obj ) {
			$searchpath = $obj.installationPath
			Write-Host "[$scriptName] Latest installed Visual Studio is $($obj.displayName)`n"
			$env:DEV_ENV = $obj.productPath
			
			$env:MS_BUILD = vswhere -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe
			if ( $env:MS_BUILD ) {
				Write-Host "[$scriptName] MSBuild found using Latest Product in VSWhere"
			}

			$testPath = vswhere -latest -products * -requires Microsoft.VisualStudio.Workload.ManagedDesktop Microsoft.VisualStudio.Workload.Web -requiresAny -property installationPath

			$elementpath = "${testPath}\${vstestContext}"
			if ( Test-Path $elementpath ) {
				$env:VS_TEST = $elementpath
				Write-Host "[$scriptName] VSTest found using Latest Product in VSWhere"
			}

			$elementpath = "${testPath}\${mstestContext}"
			if ( Test-Path $elementpath ) {
				$env:MS_TEST = $elementpath
				Write-Host "[$scriptName] MSTest found using Latest Product in VSWhere"
			}

			$list = vswhere -products * -format json | ConvertFrom-Json

			if (!( $env:MS_BUILD )) {
				foreach ($element in $list) {
					$elementpath = "$($element.installationPath)\MSBuild\Current\Bin\MSBuild.exe" 
					if ( Test-Path $elementpath ) {
						$env:MS_BUILD = $elementpath
						Write-Host "[$scriptName] MSBuild found for $($element.displayName)"
						break
					}
				}
			}

			if (!( $env:VS_TEST )) {
				foreach ($element in $list) {
					$elementpath = "$($element.installationPath)\${vstestContext}"
					if ( Test-Path $elementpath ) {
						$env:VS_TEST = $elementpath
						Write-Host "[$scriptName] vstest.console.exe found for $($element.displayName)"
						break
					}
				}
			}

			if (!( $env:MS_TEST )) {
				foreach ($element in $list) {
					$elementpath = "$($element.installationPath)\${mstestContext}"
					if ( Test-Path $elementpath ) {
						$env:MS_TEST = $elementpath
						Write-Host "[$scriptName] MSTest found for $($element.displayName)"
						break
					}
				}
			}
		}
	} else {
		Write-Host "`n[$scriptName] VSWhere installed, but not returning any data, fall back to legacy detection..."
	}
}

if (!( $env:MS_BUILD )) {
	$registryKey = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\SxS\VS7'
	if ( Test-Path $registryKey ) {
		$list = Get-ItemProperty $registryKey | Get-Member
		$installs = @()
		foreach ($element in $list) { if ($element -match '.0') { $installs += $element.Definition.Split('=')[1] }}
		$versionTest = $installs[-1] # use latest version of Visual Studio
		if ( $versionTest ) {
			Write-Host "[$scriptName][WARNING] Using MSBuild from Visual Studio 2015 or prior" -ForegroundColor Yellow
			$fileList = @(Get-ChildItem $versionTest -Recurse)
			$env:MS_BUILD = (($fileList -match 'msbuild.exe')[0]).fullname
		}
	}
}

if (!( $env:MS_BUILD )) {
	$toolsVersions = 'HKLM:\Software\Microsoft\MSBuild\ToolsVersions'
	$toolsVersions = "$toolsVersions\$((Get-Item -Path "$toolsVersions\*" -ErrorAction SilentlyContinue)[-1].Name.Split('\')[-1])"
	$toolsVersions = "$((Get-ItemProperty $toolsVersions).MSBuildToolsPath)MSBuild.exe"
	if ( $toolsVersions ) {
		if ( Test-Path $toolsVersions ) {
			Write-Host "[$scriptName][WARNING] Using MSBuild .NET legacy" -ForegroundColor Yellow
			$env:MS_BUILD = $toolsVersions
		}
	}
}

if (! ($env:VS_TEST) ) {
	$versionTest = cmd /c vstest.console.exe --help 2`>`&1
	if ( $LASTEXITCODE -eq 0 ) {
		Write-Host "[$scriptName] Found vstest.console.exe in PATH"
		$env:VS_TEST = (where.exe vstest.console.exe)[0]
	}
}

$versionTest = cmd /c NuGet 2`>`&1
if ( $LASTEXITCODE -eq 0 ) {
	$nugetPaths = (cmd /c "where.exe NuGet").Split([string[]]"`r`n",'None')
	$env:NUGET_PATH = $nugetPaths[0]
	if ( $nugetPaths.Count -gt 1 ) {
		Write-Host "`nUsing first match only for NuGet path = ${env:NUGET_PATH}. Unused paths:`n"
		for ( $i = 1; $i -lt $nugetPaths.Count ; $i++ ) {
			Write-Host "   $($nugetPaths[$i])"
		}
	}
	$array = $versionTest.split(" ")
}

if (!( $env:DEV_ENV )) {
	$registryKey = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\SxS\VS7'
	if ( Test-Path $registryKey ) {
		$list = Get-ItemProperty $registryKey | Get-Member
		$installs = @()
		foreach ($element in $list) { if ($element -match '.0') { $installs += $element.Definition.Split('=')[1] }}
		$versionTest = $installs[-1] # use latest version of Visual Studio
		if ( $versionTest ) {
			Write-Host "[$scriptName][WARNING] Using devenv from Visual Studio 2015 or prior" -ForegroundColor Yellow
			$fileList = @(Get-ChildItem $versionTest -Recurse)
			$env:DEV_ENV = (($fileList -match 'devenv.com')[0]).fullname
		}
	}
}

# Log results
if ( $env:NUGET_PATH ) {
	Write-Host "`n`$env:NUGET_PATH = ${env:NUGET_PATH} (version $($array[2]))"
} else {
	Write-Host "`n`$env:NUGET_PATH (not found)"
}

if ( $env:MS_BUILD ) {
	Write-Host "`$env:MS_BUILD = ${env:MS_BUILD}"
} else {
	Write-Host "`$env:MS_BUILD (MSBuild.exe not found)"
}

if ( $env:VS_TEST ) {
	Write-Host "`$env:VS_TEST = ${env:VS_TEST}"
} else {
	Write-Host "`$env:VS_TEST (vstest.console.exe not found)"
}

if ( $env:MS_TEST ) {
	Write-Host "`$env:MS_TEST = ${env:MS_TEST}"
} else {
	Write-Host "`$env:MS_TEST (mstest.exe not found)"
}

if ( $env:DEV_ENV ) {
	Write-Host "`$env:DEV_ENV = ${env:DEV_ENV}"
} else {
	Write-Host "`$env:DEV_ENV (devenv.exe not found)"
}

cmd /c "exit 0"
Write-Host "`n[$scriptName] --- finish---"
