Param (
	[string]$expression,
	[string]$wait,
	[string]$retryMax
)

cmd /c "exit 0"

# Only from Windows Server 2016 and above
$scriptName = 'executeRetry.ps1'

# Consolidated Error processing function
function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Red
	} else {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Yellow
	}
	if ( $error ) {
		$i = 0
		foreach ( $item in $Error )
		{
			Write-Host "`$Error[$i] $item"
			$i++
		}
		$Error.clear()
	}
	if ( $env:CDAF_ERROR_DIAG ) {
		Write-Host "`n[$scriptName] Invoke custom diag `$env:CDAF_ERROR_DIAG = $env:CDAF_ERROR_DIAG`n"
		Invoke-Expression $env:CDAF_ERROR_DIAG
	}
	if ( $exitcode ) {
		Write-Host "`n[$scriptName] Exit with LASTEXITCODE = $exitcode`n" -ForegroundColor Red
		exit $exitcode
	}
}

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
	    if(!$?) {
			ERRMSG "[HALT] `$? = $?"
			$exitCode = 1
		}
	} catch {
		ERRMSG "[EXCEPTION] $_"
		$exitCode = 2
	}
	if ( $error ) {
		ERRMSG "[WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
	}
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
		ERRMSG "[EXIT] `$lastExitCode = $lastExitCode"
		$exitCode = $lastExitCode
	}
    if ($exitCode -ne 0) {
		if ($retryCount -ge $retryMax ) {
			ERRMSG "[RETRY_EXCEEDED] Retry maximum ($retryCount) reached, exiting with `$LASTEXITCODE = $exitCode" $exitCode
		} else {
			$retryCount += 1
			Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
			Start-Sleep $wait
		}
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
$error.clear()
exit 0