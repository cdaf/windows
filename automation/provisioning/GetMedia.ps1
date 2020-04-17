Param (
	[string]$uri,
	[string]$mediaDir,
	[string]$md5,
	[string]$ignoreCertificate,
	[string]$proxy
)

$scriptName = 'GetMedia.ps1'
cmd /c "exit 0"
$error.clear()

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1011 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1012 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red ; $error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				$error
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName] `$error = $error"; exit 1013
		}
	}
}

function executeReturn ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1112 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red ; $error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				$error
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName] `$error = $error"; exit 1113
		}
	}
    return $output
}

# Retry logic for connection issues, i.e. "Cannot retrieve the dynamic parameters for the cmdlet. PowerShell Gallery is currently unavailable.  Please try again later."
# Includes warning for "Cannot find a variable with the name 'PackageManagementProvider'. Cannot find a variable with the name 'SourceLocation'."
function executeRetry ($expression) {
	$exitCode = 1
	$wait = 10
	$retryMax = 3
	$retryCount = 0
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		Write-Host "[$retryCount][$(Get-Date)] $expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?" -ForegroundColor Red; $error ; $exitCode = 1 }
		} catch { Write-Host "[$scriptName] $_" -ForegroundColor Red; $error ; $exitCode = 2 }
	    if ( $error ) { Write-Host "[$scriptName] Warning, message in `$error = $error" -ForegroundColor Yellow; $error.clear() } # do not treat messages in error array as failure
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { $exitCode = $LASTEXITCODE; Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red; cmd /c "exit 0" }
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with `$LASTEXITCODE = $exitCode.`n"
				exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Set TLS to version 1.1 or higher, Wait $wait seconds, then retry $retryCount of $retryMax"
				Write-Host "`$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'"
				$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
				executeExpression '[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols'
				Start-Sleep $wait
				$wait = $wait + $wait
			}
		}
    }
}

function listAndContinue {
	Write-Host "[$scriptName] Error accessing cache falling back to `$env:temp"
	$mediaDir = $env:temp
	$fullpath = $mediaDir + '\' + $file
	return $fullpath
}

cmd /c "exit 0"

Write-Host "`n[$scriptName] ---------- start ----------"
if ($uri) {
    Write-Host "[$scriptName] uri               : $uri"
} else {
    Write-Host "[$scriptName] uri not supplied, exiting"
    exit 101
}

if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir          : $mediaDir"
} else {
	$mediaDir = 'C:\.provision'
    Write-Host "[$scriptName] mediaDir          : $mediaDir (default)"
}

if ($md5) {
    Write-Host "[$scriptName] md5               : $md5"
} else {
    Write-Host "[$scriptName] md5               : (not supplied)"
}

if ($ignoreCertificate) {
    Write-Host "[$scriptName] ignoreCertificate : $ignoreCertificate"
    executeExpression "[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {`$true}"
} else {
    Write-Host "[$scriptName] ignoreCertificate : (not supplied)"
}

if ($proxy) {
    Write-Host "[$scriptName] proxy             : $proxy`n"
    executeExpression "[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('$proxy')"
} else {
    Write-Host "[$scriptName] proxy             : (not supplied)"
}

if ($ignoreCertificate) {
    Write-Host "[$scriptName] Configuration for ignoring certificates"
    executeExpression "[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {`$true}"
}

# Create media cache if missing
if ( Test-Path $mediaDir ) {
    Write-Host "`n[$scriptName] `$mediaDir ($mediaDir) exists"
} else {
	Write-Host "[$scriptName] Created $(mkdir $mediaDir)"
}

$file = $uri.Substring($uri.LastIndexOf("/") + 1)
$fullpath = $mediaDir + '\' + $file
if ( Test-Path $fullpath ) {
	if ( $md5 ) {
		$hashValue = executeReturn "(Get-FileHash '$fullpath' -Algorithm MD5).Hash"
		if ($hashValue -eq $md5) {
			Write-Host "[$scriptName] $fullpath exists and MD5 hash matches, download not required"
		} else {
			Write-Host "`n[$scriptName] $fullpath exists, but does not match MD5 hash, delete and download...`n"
			executeExpression "Remove-Item $fullpath"
			executeRetry "(New-Object System.Net.WebClient).DownloadFile('$uri', '$fullpath')"
			if ( $md5 ) {
				Write-Host
				$hashValue = executeReturn "(Get-FileHash '$fullpath' -Algorithm MD5).Hash"
				if ($hashValue -eq $md5) {
					Write-Host "[$scriptName] MD5 check successful"
				} else {
					Write-Host "[$scriptName] MD5 check failed! Required $md5, found $hashValue. Halting with `$lastexitcode 65"; exit 65
				}
			}
		}
	} else {
		Write-Host "[$scriptName] $fullpath exists, download not required"
	}
} else {
	Write-Host "[$scriptName] $file does not exist in $mediaDir, listing possible matches ..."
	try {
		Get-ChildItem $mediaDir $([System.IO.Path]::GetFileNameWithoutExtension($filename) + '.*') | Format-Table name
		Get-ChildItem $mediaDir $('*.' + [System.IO.Path]::GetExtension($filename)) | Format-Table name
	    if(!$?) { $fullpath = listAndContinue }
	} catch { $fullpath = listAndContinue }

	Write-Host "`n[$scriptName] Attempt download`n"
	executeRetry "(New-Object System.Net.WebClient).DownloadFile('$uri', '$fullpath')"
	if ( $md5 ) {
		Write-Host
		$hashValue = executeReturn "(Get-FileHash '$fullpath' -Algorithm MD5).Hash"
		if ($hashValue -eq $md5) {
			Write-Host "[$scriptName] MD5 check successful"
		} else {
			Write-Host "[$scriptName] MD5 check failed! Required $md5, found $hashValue. Halting with `$lastexitcode 65"; exit 65
		}
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
$error.clear()
exit 0