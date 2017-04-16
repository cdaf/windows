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

$scriptName = 'IISPoolAccount.ps1'

Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$poolid = $args[0]
if ($poolid) {
    Write-Host "[$scriptName] poolid       : $poolid"
} else {
    Write-Host "[$scriptName] poolid not supplied! Exit with code 100"; exit 100
}

$poolPassword = $args[1]
if ($poolPassword) {
    Write-Host "[$scriptName] poolPassword : *********************"
} else {
    Write-Host "[$scriptName] pool ID password not supplied! Exit with code 101"; exit 101
}

$poolName = $args[2]
if ($poolName) {
    Write-Host "[$scriptName] poolName     : $poolName"
} else {
	$poolName = 'DefaultAppPool'
    Write-Host "[$scriptName] poolName     : $poolName (default)"
}
# Provisioning Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $poolid `'**********`' $poolName `""
}

executeExpression 'Import-Module ServerManager'
executeExpression 'Import-Module WebAdministration'

try {
$appPool = get-item iis:\apppools\$poolName

} catch {
	Write-Host "[$scriptName] Sleep to ensure any previous provisioning is complete"
	sleep 5
	$appPool = get-item iis:\apppools\$poolName
}
Write-Host 
Write-Host "[$scriptName] Set ID for iis:\apppools\$poolName to $poolid"
$appPool.processModel.userName = $poolid
$appPool.processModel.password = $poolPassword
$appPool.processModel.identityType = 3
$appPool | Set-Item
$appPool.Stop()
$appPool.Start()
Write-Host "[$scriptName] IIS Recycled"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
