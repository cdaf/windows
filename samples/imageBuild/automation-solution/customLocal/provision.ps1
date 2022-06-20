Param (
	[string]$operation
)

cmd /c "exit 0"
$scriptName = 'bootstrapTarget.ps1'

function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($operation) {
    Write-Host "[$scriptName]   operation : $operation"
} else {
    Write-Host "[$scriptName]   operation : (not set)"
}

$idx = (get-eventlog -LogName System -Newest 1).Index

if ( $operation ) {

	while ($true) {
	  start-sleep -Seconds 1
	  $idx2  = (Get-EventLog -LogName System -newest 1).index
	  get-eventlog -logname system -newest ($idx2 - $idx) |  sort index
	  $idx = $idx2
	}

} else {
	executeExpression ". { iwr -useb https://cdaf.io/static/app/downloads/cdaf.ps1 } | iex"
	executeExpression ".\automation\remote\capabilities.ps1"
}
Write-Host "`n[$scriptName] ---------- stop ----------"
