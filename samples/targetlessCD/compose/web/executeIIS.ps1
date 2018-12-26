# Initialise
cmd /c "exit 0"
$scriptName = 'executeIIS.ps1'

Write-Host "`n[$scriptName] ---------- start ----------`n"

Write-Host "[$scriptName] hostname = $(hostname)"
Write-Host "[$scriptName] pwd      = $(pwd)`n"

$wait = 10
$retryMax = 3
$retryCount = 0
$exitCode = 1 # Any value other than 0 to enter the loop
while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
	$exitCode = 0
	$error.clear()
	Write-Host "[$scriptName][$retryCount] Test-Path C:\inetpub\logs\LogFiles\W3SVC1\*log"
	try {
		if ( Test-Path C:\inetpub\logs\LogFiles\W3SVC1\*log ) {
			Get-ChildItem C:\inetpub\logs\LogFiles\W3SVC1\*log
			$exitCode = 0 
		} else {
			$exitCode = 9
		}
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
	} catch { echo $_.Exception|format-list -force; $exitCode = 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; $exitCode = 3 }
	if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { $exitCode = $LASTEXITCODE; Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red; cmd /c "exit 0" }
    if ($exitCode -gt 0) {
		if ($retryCount -ge $retryMax ) {
			Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with code $exitCode"; exit $exitCode
		} else {
			$retryCount += 1
			Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
			sleep $wait
		}
	}
}

Write-Host "`n[$scriptName] ---------- IIS logging started ----------`n"

$logFile = $(Get-ChildItem C:\inetpub\logs\LogFiles\W3SVC1\*log)
Write-Host "[$scriptName] Get-Content $logFile -Wait -Tail 1000"

Get-Content $logFile -Wait -Tail 1000
