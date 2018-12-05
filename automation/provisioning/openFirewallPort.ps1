Param (
  [string]$portNumber,
  [string]$displayName
)
cmd /c "exit 0"
$scriptName = 'openFirewallPort.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 10 }
	} catch { echo $_.Exception|format-list -force; exit 11 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 12 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($portNumber) {
    Write-Host "[$scriptName] portNumber  : $portNumber"
} else {
    Write-Host "[$scriptName] portNumber not supplied, exiting with code 100"; exit 100
}

if ($displayName) {
    Write-Host "[$scriptName] displayName : $displayName"
} else {
	$displayName = $portNumber
    Write-Host "[$scriptName] displayName : not supplied, default to Port Number ($displayName)"
}

executeExpression "New-NetFirewallRule -DisplayName `"$displayName`" -Direction Inbound –Protocol TCP –LocalPort $portNumber -Action allow"

Write-Host "`n[$scriptName] ---------- stop ----------"
