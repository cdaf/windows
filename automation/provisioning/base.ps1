Param (
	[string]$install,
	[string]$mediaDir,
	[string]$proxy,
	[string]$version,
	[string]$checksum,
	[string]$otherArgs,
	[string]$autoReboot
)

cmd /c "exit 0"
$scriptName = 'base.ps1'

# Common expression logging and error handling function, output not captured to provide live output steam
function executeExpression ($expression) {
	$exitCode = 0
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName][FAILURE] `$? = $?"; $exitCode = 1 }
	} catch { Write-Host "[$scriptName][EXCEPTION] Exception details ..."; Write-Host $_.Exception|format-list -force; $exitCode = 2 }
    if ( $error ) { Write-Host "[$scriptName][ERROR] `$error[0] = $error"; $exitCode = 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName][EXIT] `$LASTEXITCODE = $LASTEXITCODE "; $exitCode = $LASTEXITCODE }
	if ( $exitCode -ne 0 ) {
		if ( $logFile ) {
			Write-Host "`n[$scriptName] Listing contents of $logFile then exit...`n"
			Get-Content $logFile
			Write-Host
		}
		exit $exitCode
	}
}

# Retry logic for connection issues, i.e. "Cannot retrieve the dynamic parameters for the cmdlet. PowerShell Gallery is currently unavailable.  Please try again later."
# Includes warning for "Cannot find a variable with the name 'PackageManagementProvider'. Cannot find a variable with the name 'SourceLocation'."
function executeRetry ($expression) {
	$exitCode = 1
	$wait = 10
	$retryMax = 3
	$retryCount = 0
	$env:rebootRequired = 'no'
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "[$retryCount] $expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?" -ForegroundColor Red; $exitCode = 1 }
		} catch { Write-Host "[$scriptName] $_" -ForegroundColor Red; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] Warning, message in `$error[0] = $error" -ForegroundColor Yellow; $error.clear() } # do not treat messages in error array as failure
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
			if ( $LASTEXITCODE -eq 3010 ) {
				Write-Host "[$scriptName] `$LASTEXITCODE = ${LASTEXITCODE}, reboot required." -ForegroundColor Yellow
				$exitCode = 0
				$env:rebootRequired = 'yes'
			} else {
				Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red
				$exitCode = $LASTEXITCODE
			}
			cmd /c "exit 0"
		}
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with `$LASTEXITCODE = $exitCode.`n"
				Write-Host "[$scriptName]   Listing log file contents ...`n"
				cat C:\ProgramData\chocolatey\logs\chocolatey.log | findstr 'ERROR'
				exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Set TLS to version 1.1 or higher, Wait $wait seconds, then retry $retryCount of $retryMax"
				Write-Host "`$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'"
				$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
				executeExpression '[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols'
				sleep $wait
				$wait = $wait + $wait
			}
		}
    }
}

Write-Host "[$scriptName] Install components using Chocolatey.`n"
Write-Host "[$scriptName] ---------- start ----------"
if ($install) {
    Write-Host "[$scriptName] install    : $install (can be space separated list)"
} else {
    Write-Host "[$scriptName] Package to install not supplied, exiting with LASTEXITCODE 4"; exit 4 
}

if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir   : $mediaDir"
} else {
	$mediaDir = '/.provision'
    Write-Host "[$scriptName] mediaDir   : $mediaDir (default)"
}

if ($proxy) {
    Write-Host "[$scriptName] proxy      : $proxy`n"
} else {
	if ( $env:http_proxy ) {
		$proxy = $env:http_proxy
	    Write-Host "[$scriptName] proxy      : $proxy (not supplied, but defaulted from `$env:http_proxy)"
    } else {
	    Write-Host "[$scriptName] proxy      : (not supplied)"
    }
}

if ($version) {
    Write-Host "[$scriptName] version    : $version`n"
    $version = "--version $version"
} else {
    Write-Host "[$scriptName] version    : (not supplied)"
}

if ($checksum) {
    Write-Host "[$scriptName] checksum   : $checksum`n"
	if ( $checksum -eq 'ignore' ) {
		$checksum = "--ignorechecksum -y"
	} else {
	    $checksum = "--checksum $checksum"
    }
} else {
    Write-Host "[$scriptName] checksum   : (not supplied)"
}

if ($otherArgs) {
    Write-Host "[$scriptName] otherArgs  : $otherArgs`n"
} else {
    Write-Host "[$scriptName] otherArgs  : (not supplied)"
}

if ($autoReboot) {
    Write-Host "[$scriptName] autoReboot : $autoReboot`n"
} else {
	$autoReboot = 'no'
    Write-Host "[$scriptName] autoReboot : $autoReboot (not supplied, set to default)"
}

Write-Host "`n[$scriptName] Set TLS to version 1.1 or higher"
Write-Host "`$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'"
$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
executeExpression '[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols'

if ($proxy) {
    Write-Host "`n[$scriptName] Load common proxy settings`n"
    executeExpression "[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('$proxy')"
    executeExpression "`$env:chocolateyProxyLocation = '$proxy'"
    executeExpression "`$env:http_proxy = '$proxy'"
}

$versionTest = cmd /c choco --version 2`>`&1
if ($versionTest -like '*not recognized*') {
	Write-Host "`n[$scriptName] Chocolatey not installed, installing ..."
	cmd /c "exit 0"
	if (!( Test-Path $mediaDir )) {
		Write-Host "[$scriptName] mkdir $mediaDir"
		Write-Host "[$scriptName]   $(mkdir $mediaDir) created"
	}
	
	Write-Host
	$file = 'install.ps1'
	$fullpath = $mediaDir + '\' + $file
	if ( Test-Path $fullpath ) {
		Write-Host "[$scriptName] $fullpath exists, download not required"
	} else {
	
		$uri = 'https://chocolatey.org/' + $file
		Write-Host "[$scriptName] $file does not exist in $mediaDir, listing contents"
		try {
			Get-ChildItem $mediaDir | Format-Table name
		    if(!$?) { $fullpath = listAndContinue }
		} catch { $fullpath = listAndContinue }

		Write-Host "[$scriptName] Attempt download"
		executeRetry "(New-Object System.Net.WebClient).DownloadFile('$uri', '$fullpath')"
	}
	
	$argList = @("$fullpath")
	$exitCode = 1
	$wait = 10
	$retryMax = 3
	$retryCount = 0
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "[$retryCount] Start-Process -FilePath 'powershell' -ArgumentList $argList -PassThru -Wait -NoNewWindow"
		try {
			$proc = Start-Process -FilePath 'powershell' -ArgumentList $argList -PassThru -Wait -NoNewWindow
			if ( $proc.ExitCode -ne 0 ) {
				Write-Host "`n[$scriptName] Process failed with exit code $proc.ExitCode`n" -ForegroundColor Red
			    $exitCode = $proc.ExitCode
			}
		} catch {
			Write-Host "[$scriptName] $file Install Exception : $_" -ForegroundColor Red
			$exitCode = 2003
		}
	    if ( $error[0] ) { Write-Host "[$scriptName] Warning, message in `$error[0] = $error" -ForegroundColor Yellow; $error.clear() } # do not treat messages in error array as failure
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with `$LASTEXITCODE = $exitCode.`n"
				Write-Host "[$scriptName]   Listing log file contents ...`n"
				cat C:\ProgramData\chocolatey\logs\chocolatey.log | findstr 'ERROR'
				exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Set TLS to version 1.1 or higher, Wait $wait seconds, then retry $retryCount of $retryMax"
				Write-Host "`$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'"
				$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
				executeExpression '[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols'
				sleep $wait
			}
		}
    }
	
	# Reload the path (without logging off and back on)
	$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

	$versionTest = cmd /c choco --version 2`>`&1
	if ($versionTest -like '*not recognized*') {
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
			$exitCode = $LASTEXITCODE
		} else {
			$exitCode = 8872
		} 
		Write-Host "[$scriptName] Chocolatey install has failed, exiting with `$LASTEXITCODE $exitCode"
		exit $exitCode
	}

}
Write-Host "[$scriptName] Chocolatey : $versionTest`n"
$rollover = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = 'C:\ProgramData\chocolatey\logs\chocolatey.log'
Add-Content $logFile "Rolling over log file to $rollover"
Copy-Item $logFile "$($logFile.TrimEnd(".log"))-${rollover}.log"
Clear-Content $logFile

# if processed as a list and any item other than the last fails, choco will return a false possitive
Write-Host "[$scriptName] Process each package separately to trap failures`n"
$install.Split(" ") | ForEach {
	executeExpression "choco upgrade -y $_ --no-progress --fail-on-standard-error $checksum $version $otherArgs"
	Write-Host "`n[$scriptName] Reload the path`n"
	executeExpression '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")'
}

if ( $env:rebootRequired -eq 'yes' ) {
	if ( $autoReboot -eq 'yes') {
	    Write-Host "[$scriptName] Reboot Required and autoReboot set to yes, rebooting in 2 seconds.`n" -ForegroundColor Green
	    executeExpression 'shutdown /r /t 2'
	} else {
	    Write-Host "[$scriptName] Reboot Required but autoReboot set to no, manual reboot is required.`n" -ForegroundColor Yellow
	}
} else {
    Write-Host "[$scriptName] Install complete, no reboot required.`n" -ForegroundColor Green
}

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0
