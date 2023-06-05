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

Write-Host '---------- Watch Windows Events to keep container alive ----------'
while ($true) {
  start-sleep -Seconds 1
  $idx2  = (Get-EventLog -LogName System -newest 1).index
  get-eventlog -logname system -newest ($idx2 - $idx) |  sort index
  $idx = $idx2
}
