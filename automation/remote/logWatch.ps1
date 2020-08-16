Param (
    [string]$logFile,
    [string]$stringMatch,
    [string]$waitTime
)

cmd /c "exit 0"
$scriptName = 'logWatch.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "`n[$scriptName] --- start ---"
if ($logFile) {
    Write-Host "[$scriptName] logFile     : $logFile"
} else {
    Write-Host "[$scriptName] logFile not supplied, exit with `$LASTEXITCODE = 101"; exit 101
}

if ($stringMatch) {
    Write-Host "[$scriptName] stringMatch : $stringMatch"
} else {
    Write-Host "[$scriptName] stringMatch not supplied, exit with `$LASTEXITCODE = 102"; exit 102
}

if ($waitTime) {
    Write-Host "[$scriptName] waitTime    : $waitTime`n"
} else {
	$waitTime = '60'
    Write-Host "[$scriptName] waitTime    : $waitTime (default)`n"
}

$wait = 5
$retryMax = [int]( $waitTime / $wait )
$retryCount = 0
$lastLineNumber = 0
$exitCode = 4365
while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
	sleep $wait
	if ( Test-Path $logFile ) {
		$output = $(cat $logFile)
		if ( $output ) {
			$lineCount = 1
		    foreach ($line in $output -split "`r`n") {
		    	if ( $lineCount -gt $lastLineNumber ) {
					Write-Host "> $line"
					$lastLineNumber = $lineCount
				}
				$lineCount += 1
		    }
		
		    if ( Select-String -Pattern $stringMatch  -InputObject $output ) {
				Write-Host "`n[$scriptName] stringMatch ($stringMatch) found."
			    $exitCode = 0
		    }
		    if ( Select-String -Pattern 'CDAF_DELIVERY_FAILURE.' -InputObject $output ) {
				Write-Host "[$scriptName] Error Detected (CDAF_DELIVERY_FAILURE.) exit with error code 335"
				$exitCode = 335
				$retryCount = $retryMax
			}
	    } else {
			Write-Host "[$scriptName]   no output ..."
	    }
    } else {
		Write-Host "[$scriptName]   no output (log file does not exist) ..."
    }
		
	if ( $retryCount -ge $retryMax ) {
		Write-Host "[$scriptName] Maximum wait time ($waitTime) reached after $retryMax retries, exiting with code $waitTime (waitTime)"
		$exitCode = $waitTime
	}
	$retryCount += 1
}

Write-Host "`n[$scriptName] --- end ---"
$error.clear()
exit $exitCode
