
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

Write-Host "`n[$scriptName] ---------- start ----------`n"

executeExpression ". { iwr -useb https://cdaf.io/static/app/downloads/cdaf.ps1 } | iex"
executeExpression ".\automation\remote\capabilities.ps1"

Write-Host "`n[$scriptName] ---------- stop ----------"
