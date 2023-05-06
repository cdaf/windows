Param (
	[string]$SOLUTION,
	[string]$BUILDNUMBER,
	[string]$ACTION
)

$scriptName = 'build.ps1'
cmd /c "exit 0"

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
Write-Host "[$scriptName] Test connectivity deployer@localhost`n"

foreach ($dirName in Get-ChildItem -Directory) {
	executeExpression "cd $dirName"
	executeExpression "..\..\automation\cdEmulate"
	executeExpression "cd .."
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0