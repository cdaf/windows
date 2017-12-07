Param (
	[string]$expression,
	[string]$wait,
	[string]$retryMax
)

# Only from Windows Server 2016 and above
$scriptName = 'executeRetry.ps1'

Write-Host "`n[$scriptName] ---------- start ----------"
if ($wait) {
    Write-Host "[$scriptName]  wait     : $wait"
} else {
	$wait = 10
    Write-Host "[$scriptName]  wait     : $wait (set to default)"
}
if ($retryMax) {
    Write-Host "[$scriptName]  retryMax : $retryMax"
} else {
	$retryMax = 5
    Write-Host "[$scriptName]  retryMax : $retryMax (set to default)"
}

$exitCode = 1
$retryCount = 0
while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
	$exitCode = 0
	$error.clear()
	Write-Host "[$scriptName][$retryCount] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
	} catch { Write-Host "[$scriptName] $_"; $exitCode = 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] Warning, message in `$error[0] = $error"; $error.clear() } # do not treat messages in error array as failure
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode "; $exitCode = $lastExitCode }
    if ($exitCode -ne 0) {
		if ($retryCount -ge $retryMax ) {
			Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with `$LASTEXITCODE = $exitCode.`n"
			exit $exitCode
		} else {
			$retryCount += 1
			Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
			sleep $wait
		}
	}
}
Write-Host "`n[$scriptName] ---------- stop ----------`n"
$error.clear()
exit 0