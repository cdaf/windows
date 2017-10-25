Param (
  [int]$buildNumber
)

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

$scriptName = 'entrypoint.ps1'

# Runtime script corresponding to containerBuild and default Docker configuration

Write-Host "`n[$scriptName] ---------- start ----------`n"
if ( $buildNumber ) {
	Write-Host "[$scriptName]   buildNumber : ${buildNumber}"
} else {
	Write-Host "[$scriptName]   buildNumber : (not supplied, CD Emulation will be used, i.e. for Vagression testing)"
}

executeExpression "cd c:\workspace"

if ( $buildNumber ) {
	executeExpression ".\automation\processor\buildPackage.ps1 $buildNumber"
} else {
	executeExpression ".\automation\cdEmulate.bat buildonly"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0