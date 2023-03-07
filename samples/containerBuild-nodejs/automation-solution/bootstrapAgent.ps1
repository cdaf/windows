$scriptName = 'bootstrapAgent.ps1'

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

cmd /c "exit 0"
# Use the CDAF provisioning helpers
Write-Host "`n[$scriptName] ---------- start ----------`n"

# If not using cdaf/windows image, install CDAF
# executeExpression '$env:CDAF_INSTALL_PATH = "c:\cdaf"'
# executeExpression '. { iwr -useb https://raw.githubusercontent.com/cdaf/windows/master/install.ps1 } | iex'

Write-Host "[$scriptName] Mutually Exclusive Components can be installed`n"
executeExpression "base.ps1 'nodejs-lts'"
executeExpression "npm install -g yo"
executeExpression "npm install -g generator-rest"

executeExpression "capabilities.ps1"

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0 