# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
}

$scriptName = 'base.ps1'
Write-Host "[$scriptName] ---------- start ----------"
Write-Host
Write-Host "[$scriptName] Install components using Chocolatey."
Write-Host
$install = $args[0]
if ($install) {
    Write-Host "[$scriptName] install   : $install"
} else {
    Write-Host "[$scriptName] Package to install not supplied, exiting"
}

Write-Host
executeExpression "choco install -y $install --fail-on-standard-error"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
