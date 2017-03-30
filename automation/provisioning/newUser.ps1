# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    return $output
}

function executeRetry ($expression) {
	$wait = 10
	$retryMax = 10
	$retryCount = 0
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "[$scriptName][$retryCount] $expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
		} catch { echo $_.Exception|format-list -force; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; $exitCode = 3 }
	    if ($exitCode -gt 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with code $exitCode"; exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
				sleep $wait
			}
		}
    }
}

$scriptName = 'newUser.ps1'
Write-Host
Write-Host "[$scriptName] New User on Domain or Workgroup, Windows Server 2012 and above"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$userName = $args[0]
if ($userName) {
    Write-Host "[$scriptName] userName             : $userName"
} else {
	$userName = 'Deployer'
    Write-Host "[$scriptName] userName             : $userName (default)"
}

$password = $args[1]
if ($password) {
    Write-Host "[$scriptName] password             : **********"
} else {
	$password = 'swUwe5aG'
    Write-Host "[$scriptName] password             : ********** (default)"
}

$TrustedForDelegation = $args[2]
if ($TrustedForDelegation) {
    Write-Host "[$scriptName] TrustedForDelegation : $TrustedForDelegation (choices yes or no)"
} else {
	$TrustedForDelegation = 'no'
    Write-Host "[$scriptName] TrustedForDelegation : $TrustedForDelegation (default, choices yes or no)"
}

# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName `"$userName`" `"**********`"`""
}

if ((gwmi win32_computersystem).partofdomain -eq $true) {

	executeRetry  "Import-Module ActiveDirectory"

	Write-Host "`n[$scriptName] Add the new user, enabled with password`n"
	executeRetry  "New-ADUser -Name $userName -AccountPassword (ConvertTo-SecureString -AsPlainText `$password -Force)"
	executeRetry  "Enable-ADAccount -Identity $userName"

	if ($TrustedForDelegation -eq 'yes') {
		executeRetry  "Set-ADUser -Identity $userName -TrustedForDelegation `$True"
	}

} else {

	if ($TrustedForDelegation -eq 'yes') {
	    Write-Host "[$scriptName] TrustedForDelegation is not applicable to workgroup computer, no action will be attempted."
	}

	Write-Host "`n[$scriptName] Workgroup Host, create as local user ($userName)."
	$ADSIComp = executeExpression "[ADSI]`"WinNT://$Env:COMPUTERNAME,Computer`""
	$LocalUser = executeExpression "`$ADSIComp.Create(`'User`', `"$userName`")"
	executeExpression "`$LocalUser.SetPassword(`$password)"
	executeExpression "`$LocalUser.SetInfo()"
	executeExpression "`$LocalUser.FullName = `"$userName`""
	executeExpression "`$LocalUser.SetInfo()"

}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
