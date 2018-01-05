Param (
	[string]$install
)

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

$scriptName = 'base.ps1'
Write-Host "[$scriptName] Install components using Chocolatey.`n"
Write-Host "[$scriptName] ---------- start ----------"
if ($install) {
    Write-Host "[$scriptName] install : $install"
} else {
    Write-Host "[$scriptName] Package to install not supplied, exiting with LASTEXITCODE 4"; exit 4 
}

Write-Host
executeExpression "choco install -y $install --no-progress --fail-on-standard-error"

Write-Host "`n[$scriptName] Reload the path`n"
executeExpression '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")'

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0
