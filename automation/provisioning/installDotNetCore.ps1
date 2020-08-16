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

# As at dotnet 2 runtime files have changed https://www.microsoft.com/net/download/dotnet-core/2.1
# ASP.NET Core/.NET Core	dotnet-hosting-2.1.x-win.exe         (no)
# ASP.NET Core Installer	aspnetcore-runtime-2.1.x-win-x64.exe (asp)
# .NET Core Binaries		dotnet-runtime-2.1.x-win-x64.exe     (not supported)

Write-Host "`n[$scriptName] ---------- start ----------"
if ( $sdk ) {
	Write-Host "[$scriptName] sdk      : $sdk (choices yes, no or asp)"
} else {
	$sdk = 'no'
	Write-Host "[$scriptName] sdk      : $sdk (default, choices yes, no or asp)"
}

if ( $version ) {
	Write-Host "[$scriptName] version  : $version"
} else {
	if ( $sdk -eq 'yes' ) {
		$version = '2.2.105'
		$file = "dotnet-sdk-${version}-win-x64.exe"
		$url = "https://download.visualstudio.microsoft.com/download/pr/8148cce0-196d-4634-86df-f3d4550b1a75/89ed68d0ecf6b1c62cc7b0d129fdf600/${file}"
	} else {
		$version = '2.2.3'
		if ( $sdk -eq 'asp' ) {
			$file = "aspnetcore-runtime-${version}-win-x64.exe"
			$url = "https://download.visualstudio.microsoft.com/download/pr/e00f77e4-e397-438f-a5d2-9a9c221fd2e0/8bac1cc1d685af687fac8072cf19ba58/${file}"
		} else {
			$file = "dotnet-hosting-${version}-win.exe"
			$url = "https://download.visualstudio.microsoft.com/download/pr/a46ea5ce-a13f-47ff-8728-46cb92eb7ae3/1834ef35031f8ab84312bcc0eceb12af/${file}"	
		}
	} 
	Write-Host "[$scriptName] version  : $version (default)"
}

if ( $mediaDir ) {
	Write-Host "[$scriptName] mediaDir : $mediaDir`n"
} else {
	$mediaDir = $(Get-Location)
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

$proc = executeExpression "Start-Process -FilePath '$installer' -ArgumentList '/INSTALL /QUIET /NORESTART /LOG $installer.log' -PassThru -Wait"
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName][EXIT] List $installer.log and exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
	Get-Content $installer.log
    exit $proc.ExitCode
}

Write-Host "[$scriptName] Reload path (without logging off and back on) " -ForegroundColor Green
$env:Path = executeExpression "[System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')"

$(dotnet --info | select-string -pattern 'Version')
if ($versionTest -like '*not recognized*') {
	Write-Host "  dotnet core not installed! Exiting with error 666"; exit 666
} else {
	$versionLine = $(foreach ($line in dotnet) { Select-String  -InputObject $line -CaseSensitive "Version" })
	if ( $versionLine ) {
	$arr = $versionLine -split ':'
		Write-Host "  dotnet core : $($arr[1])"
	} else {
		Write-Host "  dotnet core : $versionTest"
	}
}

Write-Host "`n[$scriptName] ---------- stop -----------"
exit 0