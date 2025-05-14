Param (
  [string]$poolid,
  [string]$poolPassword,
  [string]$poolName
)

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

$scriptName = 'IISPoolAccount.ps1'

Write-Host
Write-Host "[$scriptName] ---------- start ----------"
if ($poolid) {
    Write-Host "[$scriptName] poolid       : $poolid"
} else {
    Write-Host "[$scriptName] poolid not supplied! Exit with code 100"; exit 100
}

if ($poolPassword) {
    Write-Host "[$scriptName] poolPassword : *********************"
} else {
    Write-Host "[$scriptName] poolPassword : not supplied (assuming Managed Service Account)"
}

if ($poolName) {
    Write-Host "[$scriptName] poolName     : $poolName"
} else {
	$poolName = 'DefaultAppPool'
    Write-Host "[$scriptName] poolName     : $poolName (default)"
}

executeExpression 'Import-Module ServerManager'
executeExpression 'Import-Module WebAdministration'

try {
	$appPool = get-item iis:\apppools\$poolName
} catch {
	Write-Host "[$scriptName] Sleep to ensure any previous provisioning is complete"
	Start-Sleep 5
	$appPool = get-item iis:\apppools\$poolName
}

Write-Host "`n[$scriptName] Set ID for iis:\apppools\$poolName to $poolid"
$appPool.processModel.userName = $poolid
if ($poolPassword) {
	$appPool.processModel.password = $poolPassword
}
$appPool.processModel.identityType = 'SpecificUser'
$appPool | Set-Item
$appPool.Stop()
$appPool.Start()

Write-Host "[$scriptName] IIS Recycled"

Write-Host "`n[$scriptName] ---------- stop ----------"
