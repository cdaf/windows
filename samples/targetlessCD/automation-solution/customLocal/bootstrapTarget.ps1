
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

Write-Host "[$scriptName] Download latest from GitHub`n"
executeExpression '$env:CDAF_INSTALL_PATH = "c:\cdaf"'
executeExpression '. { iwr -useb https://raw.githubusercontent.com/cdaf/windows/master/install.ps1 } | iex'

Write-Host "[$scriptName] Add any provisioning needed here`n"
executeExpression "capabilities.ps1"

Write-Host "`n[$scriptName] ---------- stop ----------"
