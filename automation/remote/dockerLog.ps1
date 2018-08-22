Param (
    [string]$container,
    [string]$stringMatch,
    [string]$waitTime
)

cmd /c "exit 0"
$scriptName = 'dockerLog.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "`n[$scriptName] --- start ---"
if ($container) {
	if ( $container -eq 'DOCKER-COMPOSE' ) {
	    Write-Host "[$scriptName] container   : $container (will use docker-compose logs)"
	} else {
	    Write-Host "[$scriptName] container   : $container"
	}
} else {
    Write-Host "[$scriptName] container not supplied, exit with `$LASTEXITCODE = 101"; exit 101
}

if ($stringMatch) {
    Write-Host "[$scriptName] stringMatch : $stringMatch"
} else {
    Write-Host "[$scriptName] stringMatch not supplied, exit with `$LASTEXITCODE = 102"; exit 102
}

if ($waitTime) {
    Write-Host "[$scriptName] waitTime    : $waitTime"
} else {
	$waitTime = '60'
    Write-Host "[$scriptName] waitTime    : $waitTime (default)"
}

if ( Test-Path test.log ) { Remove-Item -Force test.log }
if ( Test-Path prevtest.log ) { Remove-Item -Force prevtest.log }

$wait = 5
$retryMax = [int]( $waitTime / $wait )
$retryCount = 0
$lastLineNumber = 0
$exitCode = 4365
while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
	sleep $wait
	if ( $container -eq 'DOCKER-COMPOSE' ) {
		$output = $(docker-compose logs)
	} else {
		$output = $(docker logs $container)
	}
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
			Write-Host "[$scriptName] stringMatch ($stringMatch) found."
		    $exitCode = 0
	    }
    } else {
		Write-Host "[$scriptName]   no output ..."
    }
		
	if ( $retryCount -ge $retryMax ) {
		Write-Host "[$scriptName] Retry maximum ($retryMax) reached, exiting with code 334"; $exitCode = 334
	}
	$retryCount += 1
}

Write-Host "`n[$scriptName] --- end ---"
$error.clear()
exit $exitCode
