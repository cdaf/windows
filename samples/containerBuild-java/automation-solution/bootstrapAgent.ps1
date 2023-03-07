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

executeExpression '$env:CDAF_INSTALL_PATH = "c:\cdaf"'
executeExpression '. { iwr -useb https://raw.githubusercontent.com/cdaf/windows/master/install.ps1 } | iex'

Write-Host "[$scriptName] List components of the base image`n"
executeExpression "base.ps1 'microsoft-openjdk11'"
executeExpression "base.ps1 'maven' -otherArgs '--ignore-dependencies'" # avoid Oracle Java dependency
executeExpression "capabilities.ps1"

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0 