Param (
	[string]$ENVIRONMENT
)

# Initialise
cmd /c "exit 0"
$scriptName = 'executeTest.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Output $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

function executeRetry ($expression) {
	$wait = 10
	$retryMax = 3
	$retryCount = 0
	$exitCode = 1 # Any value other than 0 to enter the loop
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "[$scriptName][$retryCount] $expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
			if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
				$exitCode = $LASTEXITCODE; Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Yellow; cmd /c "exit 0"
			}
		} catch { 
			if ( $error ) {
				Write-Host "[$scriptName] `$error[0] = $error" ; $error.clear() ; $exitCode = 3
			} else {
				Write-Output $_.Exception|format-list -force ; $exitCode = 2
			}
		}
	    if ($exitCode -gt 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with code $exitCode"; exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
				Start-Sleep $wait
			}
		}
    }
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($ENVIRONMENT) {
    Write-Host "[$scriptName]  ENVIRONMENT : $ENVIRONMENT"
} else {
    Write-Host "[$scriptName]  ENVIRONMENT : (not supplied)" 
}

Write-Host "`n[$scriptName] Execute CDAF Delivery`n"
executeExpression ".\TasksLocal\delivery.bat $ENVIRONMENT"

Write-Host "`n[$scriptName] Automated Test Execution completed successfully."

Write-Host '---------- Watch Windows Events to keep container alive ----------'
while ($true) {
  start-sleep -Seconds 10
  $idx2  = (Get-EventLog -LogName System -newest 1).index
  get-eventlog -logname system -newest ($idx2 - $idx) |  sort index
  $idx = $idx2
}
