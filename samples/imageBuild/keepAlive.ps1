Param (
	[string]$ENVIRONMENT
)

# Initialise
cmd /c "exit 0"
$scriptName = 'keepAlive.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "`n[$scriptName] ---------- start ----------`n"
if ($ENVIRONMENT) {
    Write-Host "[$scriptName] ENVIRONMENT : $ENVIRONMENT"
} else {
    Write-Host "[$scriptName] ENVIRONMENT : (not supplied)" 
}

Write-Host "`n[$scriptName] Execute CDAF Delivery`n"
executeExpression ".\TasksLocal\delivery.bat $ENVIRONMENT"

$logFile = "$env:TEMP\psd.log"
Add-Content $logFile '[START] ---------- Watch log to keep container alive ----------'
Add-Content $logFile "[START] $(date)"
Write-Host "[$scriptName] Get-Content $logFile -Wait -Tail 1000"

Get-Content $logFile -Wait -Tail 1000
