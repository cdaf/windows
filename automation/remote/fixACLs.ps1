Param (
	[string]$path
)
$scriptName = 'fixACLs.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($path) {
    Write-Host "[$scriptName] path : $path"
} else {
	$path = 'C:\inetpub\wwwroot\'
    Write-Host "[$scriptName] path : $path (not passed so set to default)"
}

if ( ! ( Test-Path $path )) {
	Write-Host "`n[$scriptName] Created directory $(mkdir $path)"
}

Write-Host "`n[$scriptName] `$acl = Get-Acl $path"
$acl = Get-Acl $path
executeExpression "Set-Acl '$path' `$acl"

Write-Host "`n[$scriptName] --- end ---"
$error.clear()
exit 0
