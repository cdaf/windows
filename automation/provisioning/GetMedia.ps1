Param (
	[string]$uri,
	[string]$mediaDir,
	[string]$md5
)
$scriptName = 'GetMedia.ps1'

# Retry logic for connection issues, i.e. "Cannot retrieve the dynamic parameters for the cmdlet. PowerShell Gallery is currently unavailable.  Please try again later."
# Includes warning for "Cannot find a variable with the name 'PackageManagementProvider'. Cannot find a variable with the name 'SourceLocation'."
function executeRetry ($expression) {
	$exitCode = 1
	$wait = 10
	$retryMax = 3
	$retryCount = 0
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "[$retryCount] $expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?" -ForegroundColor Red; $exitCode = 1 }
		} catch { Write-Host "[$scriptName] $_" -ForegroundColor Red; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] Warning, message in `$error[0] = $error" -ForegroundColor Yellow; $error.clear() } # do not treat messages in error array as failure
	    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode " -ForegroundColor Red; $exitCode = $lastExitCode }
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
				sleep $wait
				$wait = $wait + $wait
			}
		}
    }
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
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
    Write-Host "[$scriptName] uri      : $uri"
} else {
    Write-Host "[$scriptName] uri not supplied, exiting"
    exit 101
}

if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = 'C:\.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

if ($md5) {
    Write-Host "[$scriptName] md5      : $md5"
} else {
    Write-Host "[$scriptName] md5      : (not supplied)"
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
	Write-Host "[$scriptName] $fullpath exists, download not required"
} else {
	Write-Host "[$scriptName] $file does not exist in $mediaDir, listing contents"
	try {
		Get-ChildItem $mediaDir | Format-Table name
	    if(!$?) { $fullpath = listAndContinue }
	} catch { $fullpath = listAndContinue }

	Write-Host "[$scriptName] Attempt download"
	executeRetry "(New-Object System.Net.WebClient).DownloadFile('$uri', '$fullpath')"
}

if ( $md5 ) {
	Write-Host
	$hashValue = executeExpression "Get-FileHash '$fullpath' -Algorithm MD5"
	if ($hashValue = $md5) {
		Write-Host "[$scriptName] MD5 check successful"
	} else {
		Write-Host "[$scriptName] MD5 check failed! Halting with `$lastexitcode 65"; exit 65
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
$error.clear()
exit 0