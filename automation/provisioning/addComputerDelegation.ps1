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

$scriptName = 'addComputerDelegation.ps1'
Write-Host "`n[$scriptName] Allow a computer to delegate user credentials, combines with setSPN.ps1"
Write-Host "[$scriptName] If on the domain controller, use setSPN.ps1 computer <computerName>"
Write-Host "`n[$scriptName] ---------- start ----------"
$forest = $args[0]
if ($forest) {
    Write-Host "[$scriptName] forest           : $forest"
} else {
	$forest = 'sky.net'
    Write-Host "[$scriptName] forest           : $forest (default)"
}

$domainAdminUser = $args[1]
if ($domainAdminUser) {
    Write-Host "[$scriptName] domainAdminUser  : $domainAdminUser"
} else {
	$domainAdminUser = 'vagrant'
    Write-Host "[$scriptName] domainAdminUser  : $domainAdminUser (default)"
}

$domainAdminPass = $args[2]
if ($domainAdminPass) {
    Write-Host "[$scriptName] domainAdminPass  : **********"
} else {
	$domainAdminPass = 'vagrant'
    Write-Host "[$scriptName] domainAdminPass  : ********** (default)"
}

$domainController = $args[3]
if ($domainController) {
    Write-Host "[$scriptName] domainController : $domainController"
} else {
	$domainController = '172.16.17.102'
    Write-Host "[$scriptName] domainController : $domainController (default)"
}
# Provisioning Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $forest $domainAdminUser ********** $domainController `""
}

$securePassword = ConvertTo-SecureString $domainAdminPass -asplaintext -force
$cred = New-Object System.Management.Automation.PSCredential ($domainAdminUser, $securePassword)

Write-Host "`n[$scriptName] Set this computer ($(hostname)) delegation privileges on domain ($forest)"
executeExpression "Invoke-Command -ComputerName $domainController -Credential `$cred -ScriptBlock { Set-ADComputer -Identity $(hostname) -TrustedForDelegation `$True } "

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0