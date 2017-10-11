Param (
  [string]$SOLUTION,
  [string]$BUILD,
  [string]$ENVIRONMENT
)

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

$scriptName = 'customDelivery.ps1'
Write-Host "`n[$scriptName] ---------- start ----------`n"
Write-Host "[$scriptName] SOLUTION    : $SOLUTION"
Write-Host "[$scriptName] BUILD       : $BUILD"
Write-Host "[$scriptName] ENVIRONMENT : $ENVIRONMENT"

executeExpression "dir"

Write-Host "`n[$scriptName] ---------- stop ----------"
