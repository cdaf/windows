Param (
	[string]$SOLUTION,
	[string]$BUILDNUMBER,
	[string]$REVISION,
	[string]$PROJECT,
	[string]$ENVIRONMENT,
	[string]$ACTION
)

$scriptName = 'build.ps1'
cmd /c "exit 0"

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
	$exitCode = 1
	$wait = 10
	$retryMax = 5
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
	    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode "; $exitCode = $LASTEXITCODE }
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, listing docker images and processes for diagnostics and exiting with `$LASTEXITCODE = $exitCode.`n"
				Write-Host "[$scriptName] docker images`n"
				docker images
				Write-Host "`n[$scriptName] docker ps`n"
				docker ps
				Write-Host "`n[$scriptName] docker-compose logs`n"
				docker-compose logs
				exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
				Write-Host "[$scriptName] docker-compose logs`n"
				docker-compose logs
				sleep $wait
			}
		}
    }
}

Write-Host "`n[$scriptName] ---------- start ----------`n"
Write-Host "[$scriptName]   SOLUTION    : $SOLUTION"
Write-Host "[$scriptName]   BUILDNUMBER : $BUILDNUMBER"
Write-Host "[$scriptName]   REVISION    : $REVISION"
Write-Host "[$scriptName]   PROJECT     : $PROJECT"
Write-Host "[$scriptName]   ENVIRONMENT : $ENVIRONMENT"
Write-Host "[$scriptName]   ACTION      : $ACTION"

# Properties file loader, all properties are instantiated as runtime variables and listed in the logs
write-host "The transform does not support relative paths, so the parent path must be resolved before invokation"
$parentPath = (Get-Item -Path "..\" -Verbose).FullName
..\autodeploy\remote\Transform.ps1 "$parentPath\autodeploy\solution\propertiesForLocalTasks\$ENVIRONMENT" | ForEach-Object { invoke-expression $_ }

executeExpression "dir"

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0