$scriptName = 'buildAgent.ps1'

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

# Use the CDAF provisioning helpers
Write-Host "`n[$scriptName] ---------- start ----------`n"

if ( Test-Path "c:\vagrant" ) {
	executeExpression 'cd c:\vagrant'
}

Write-Host "[$scriptName] List components of the base image`n"
executeExpression './automation/remote/capabilities.ps1'

executeExpression './automation/provisioning/installDotnetCore.ps1 -sdk yes'

Write-Host "`n[$scriptName] ---------- stop ----------"
