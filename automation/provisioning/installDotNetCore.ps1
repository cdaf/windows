Param (
	[string]$sdk,
	[string]$version,
	[string]$mediaDir,
	[string]$proxy
)

cmd /c "exit 0"
$Error.Clear()
$scriptName = 'installDotnetCore.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1112 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red ; $error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE, $error[] = $error`n" -ForegroundColor Yellow
				$error.clear()
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName][WARN] $Error array populated but LASTEXITCODE not set, $error[] = $error`n" -ForegroundColor Yellow
			$error.clear()
		}
	}
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ( $sdk ) {
	Write-Host "[$scriptName] sdk      : $sdk (choices yes, asp for IIS Hosting or runtime only)"
} else {
	$sdk = 'yes'
	Write-Host "[$scriptName] sdk      : $sdk (default, choices yes, asp for IIS Hosting or runtime only)"
}

if ( $version ) {
	Write-Host "[$scriptName] version  : $version"
} else {
	$version = '6'
	Write-Host "[$scriptName] version  : $version (default)"
}

if ( $version -eq '2' ) {
	if ( $sdk -eq 'yes' ) {
		$version = '2.2.105'
		$file = "dotnet-sdk-${version}-win-x64.exe"
		$url = "https://download.visualstudio.microsoft.com/download/pr/8148cce0-196d-4634-86df-f3d4550b1a75/89ed68d0ecf6b1c62cc7b0d129fdf600/${file}"
	} else {
		$version = '2.2.3'
		if ( $sdk -eq 'asp' ) {
			$file = "dotnet-hosting-${version}-win.exe"
			$url = "https://download.visualstudio.microsoft.com/download/pr/a46ea5ce-a13f-47ff-8728-46cb92eb7ae3/1834ef35031f8ab84312bcc0eceb12af/${file}"	
		} else {
			$file = "aspnetcore-runtime-${version}-win-x64.exe"
			$url = "https://download.visualstudio.microsoft.com/download/pr/e00f77e4-e397-438f-a5d2-9a9c221fd2e0/8bac1cc1d685af687fac8072cf19ba58/${file}"
		}
	} 
} elseif ( $version -eq '3' ) {
	if ( $sdk -eq 'yes' ) {
		$version = '3.1.409'
		$file = "dotnet-sdk-${version}-win-x64.exe"
		$url = "https://download.visualstudio.microsoft.com/download/pr/d144f312-0922-4c92-a13f-9ffdf946525e/f5fd0de3cc3a88ba6bdb515e6e4dc41a/${file}"
	} else {
		$version = '3.1.15'
		if ( $sdk -eq 'asp' ) {
			$file = "dotnet-hosting-${version}-win.exe"
			$url = "https://download.visualstudio.microsoft.com/download/pr/c8eabe25-bb2b-4089-992e-48198ff72ad8/a55a5313bfb65ac9bd2e5069dd4de5bc/${file}"	
		} else {
			$file = "aspnetcore-runtime-${version}-win-x64.exe"
			$url = "https://download.visualstudio.microsoft.com/download/pr/ae6e6b5b-5e7c-45f9-a668-cb1899f22e46/9c917acfab934ddd64340ba46490264e/${file}"
		}
	} 
} elseif ( $version -eq '5' ) {
	if ( $sdk -eq 'yes' ) {
		$version = '5.0.301'
		$file = "dotnet-sdk-${version}-win-x64.exe"
		$url = "https://download.visualstudio.microsoft.com/download/pr/ced7fd9b-73b9-4756-b9a4-e887281b8c82/7ab0a8e6e8257f1322c6b63a5e01fcb9/${file}"
	} else {
		$version = '5.0.7'
		if ( $sdk -eq 'asp' ) {
			$file = "dotnet-hosting-${version}-win.exe"
			$url = "https://download.visualstudio.microsoft.com/download/pr/2a40c007-8ad7-4e80-a334-40bc47851e90/fc13a55a20414ef9689fcf60618c412f/${file}"
		} else {
			$file = "aspnetcore-runtime-${version}-win-x64.exe"
			$url = "https://download.visualstudio.microsoft.com/download/pr/64ae43e4-fcf0-4247-80ec-ac87d7f198f7/af4cec1666bbc03578442c174f4ad4be/${file}"
		}
	} 
} elseif ( $version -eq '6' ) {
	if ( $sdk -eq 'yes' ) {
		$version = '6.0.403'
		$file = "dotnet-sdk-${version}-win-x64.exe"
		$url = "https://download.visualstudio.microsoft.com/download/pr/08ada4db-1e64-4829-b36d-5beb71f67bff/b77050cf7e0c71d3b95418651db1a9b8/${file}"
	} else {
		$version = '6.0.11'
		if ( $sdk -eq 'asp' ) {
			$file = "dotnet-hosting-${version}-win.exe"
			$url = "https://download.visualstudio.microsoft.com/download/pr/db07eed5-297a-45b8-bea2-1e93c623a88c/6e5a8d3432e6213f071be3751ae53a08/${file}"
		} else {
			$file = "aspnetcore-runtime-${version}-win-x64.exe"
			$url = "https://download.visualstudio.microsoft.com/download/pr/e874914f-d43d-4b61-8479-f6a5536e44b1/7043adfe896aa9f980ce23e884aae37d/${file}"
		}
	} 
} else {
	Write-Host "[$scriptName] version $version not supported!";
	exit 8873
}
 
if ( $mediaDir ) {
	Write-Host "[$scriptName] mediaDir : $mediaDir`n"
} else {
	$testFile = ([guid]::NewGuid()).tostring()
	$mediaDir = $Env:USERPROFILE
	try {
		Add-Content "$mediaDir\$testFile" "$((Get-Date).ToString())"
	} catch {
		$mediaDir = $(Get-Location)
		executeExpression "Add-Content $mediaDir\$testFile '$((Get-Date).ToString())'"
	}
	Remove-Item "$mediaDir\$testFile"
	Write-Host "[$scriptName] mediaDir : $mediaDir (not passed, set to default)`n"
}

if ($proxy) {
    Write-Host "[$scriptName] proxy    : $proxy`n"
    executeExpression "[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('$proxy')"
} else {
	if ( $env:http_proxy ) {
	    Write-Host "[$scriptName] proxy    : $env:http_proxy (not supplied but derived from `$env:http_proxy)"
	    executeExpression "[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('$env:http_proxy')"
	} else {
	    Write-Host "[$scriptName] proxy    : (not supplied)"
    }
}

# Create media cache if missing
if ( Test-Path $mediaDir ) {
    Write-Host "`n[$scriptName] `$mediaDir ($mediaDir) exists"
} else {
	Write-Host "[$scriptName] Created $(mkdir $mediaDir)"
}

$installer = "${mediaDir}\${file}"
if ( Test-Path $installer ) {
	Write-Host "[$scriptName] Installer $installer found, download not required`n"
} else {
	Write-Host "[$scriptName] $file does not exist in $mediaDir, listing contents"
	try {
		Get-ChildItem $mediaDir | Format-Table name
	    if(!$?) { $installer = listAndContinue }
	} catch { $installer = listAndContinue }

	Write-Host "[$scriptName] Attempt download"
	executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$installer')"
}

Write-Host "Start-Process -FilePath '$installer' -ArgumentList '/INSTALL /QUIET /NORESTART /LOG $installer.log' -PassThru -Wait"
$proc = Start-Process -FilePath "$installer" -ArgumentList "/INSTALL /QUIET /NORESTART /LOG $installer.log" -PassThru -Wait
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName][EXIT] List $installer.log and exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
	Get-Content $installer.log
    exit $proc.ExitCode
}

Write-Host "[$scriptName] Reload path (without logging off and back on) " -ForegroundColor Green
executeExpression '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")'

if ( $sdk -eq 'yes' ) {
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
	}
}

Write-Host "`n[$scriptName] ---------- stop -----------"
exit 0