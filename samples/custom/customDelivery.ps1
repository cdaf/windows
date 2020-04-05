Param (
  [string]$SOLUTION,
  [string]$BUILD,
  [string]$ENVIRONMENT
)

$Error.Clear()
cmd /c "exit 0"
$scriptName = 'customDelivery.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------`n"
Write-Host "[$scriptName] SOLUTION    : $SOLUTION"
Write-Host "[$scriptName] BUILD       : $BUILD"
Write-Host "[$scriptName] ENVIRONMENT : $ENVIRONMENT"
Write-Host "[$scriptName] TARGET      : $TARGET"

& ./Transform.ps1 $TARGET | ForEach-Object { invoke-expression $_ }

executeExpression "dir"

Write-Host "`n[$scriptName] ---------- stop ----------"
