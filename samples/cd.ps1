Param (
	[string]$buildNumber,
	[string]$branchName
)

$scriptName = 'ci.ps1'
cmd /c "exit 0"

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$result = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $result
}


Write-Host "`n[$scriptName] ---------- start ----------`n"
Write-Host "[$scriptName]   buildNumber : $buildNumber"
Write-Host "[$scriptName]   branchName  : $branchName"


executeExpression "hostname"
executeExpression "whoami"
	
Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0