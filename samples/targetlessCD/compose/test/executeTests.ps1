Param (
	[string]$url,
	[string]$title
)

# Initialise
cmd /c "exit 0"
$scriptName = 'executeTests.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
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
}

Write-Host "`n[$scriptName] ---------- start ----------`n"
if ($url) {
    Write-Host "[$scriptName] url   : $url"
} else {
    Write-Host "[$scriptName] url   : (not supplied, will only test Google)" 
}

if ($title) {
    Write-Host "[$scriptName] title : $title"
} else {
    Write-Host "[$scriptName] title : (not supplied, will only test Google)" 
}

Write-Host "[$scriptName] hostname = $(hostname)"
Write-Host "[$scriptName] pwd      = $(pwd)`n"

Write-Host "[$scriptName] Run the tests`n"

if ($url) {
	executeExpression "java -jar $(dir Portable-*-jar-with-dependencies.jar) '$url' '$title'"
}

executeExpression 'java -jar $(dir Portable-*-jar-with-dependencies.jar)'

Write-Host "`n[$scriptName] Automated Test Execution completed successfully."

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
cmd /c "exit 0"
