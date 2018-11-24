Param (
  [string]$userName,
  [string]$password,
  [string]$TrustedForDelegation,
  [string]$passwordExpires
)

cmd /c "exit 0"
$scriptName = 'newUser.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

function localUser ($userName, $password) {
	Write-Host "`n[$scriptName] Workgroup Host, create as local user ($userName)."
	$ADSIComp = executeExpression "[ADSI]`"WinNT://$Env:COMPUTERNAME,Computer`""
	$LocalUser = executeExpression "`$ADSIComp.Create(`'User`', `"$userName`")"
	executeExpression "`$LocalUser.SetPassword(`$password)"
	executeExpression "`$LocalUser.SetInfo()"
	executeExpression "`$LocalUser.FullName = `"$userName`""
	executeExpression "`$LocalUser.SetInfo()"
	if ($passwordExpires -eq 'no') {
		executeExpression "`$LocalUser.UserFlags.value = `$LocalUser.UserFlags.value -bor 0x10000" # Password never expires
		executeExpression "`$LocalUser.SetInfo()"
	} 
	executeExpression "`$LocalUser.CommitChanges()"
}

function executeRetry ($expression) {
	$wait = 10
	$retryMax = 3
	$retryCount = 0
	$exitCode = 1 # Any value other than 0 to enter the loop
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "[$scriptName][$retryCount] $expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
		} catch { echo $_.Exception|format-list -force; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; $exitCode = 3 }
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { $exitCode = $LASTEXITCODE; Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red; cmd /c "exit 0" }
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

Write-Host "`n[$scriptName] New User on Domain or Workgroup, Windows Server 2012 and above"
Write-Host "`n[$scriptName] If creating a local account, on a domain registered machine, prefix username with .\"
Write-Host "`n[$scriptName] ---------- start ----------"
if ($userName) {
    Write-Host "[$scriptName] userName             : $userName"
} else {
	$userName = 'Deployer'
    Write-Host "[$scriptName] userName             : $userName (default)"
}

if ($password) {
    Write-Host "[$scriptName] password             : **********"
} else {
	$password = 'swUwe5aG'
    Write-Host "[$scriptName] password             : ********** (default)"
}

if ($TrustedForDelegation) {
    Write-Host "[$scriptName] TrustedForDelegation : $TrustedForDelegation (choices yes or no)"
} else {
	$TrustedForDelegation = 'no'
    Write-Host "[$scriptName] TrustedForDelegation : $TrustedForDelegation (default, choices yes or no)"
}

if ($passwordExpires) {
    Write-Host "[$scriptName] passwordExpires      : $passwordExpires (choices yes or no)"
} else {
	$passwordExpires = 'yes'
    Write-Host "[$scriptName] passwordExpires      : $passwordExpires (default, choices yes or no)"
}

if ( $userName.StartsWith('.\')) { 
	localUser $userName.Substring(2) $password # Remove the .\ prefix
} else {

	if ((gwmi win32_computersystem).partofdomain -eq $true) {

		if ($passwordExpires -eq 'no') {
			Write-Host "`n[$scriptName] Password expiry setting only applicable to local accounts`n"
		}
	
		if ( (Get-WindowsFeature RSAT-AD-PowerShell).installstate -eq 'Available' ) {
			executeRetry "Add-WindowsFeature RSAT-AD-PowerShell"
		}
		executeRetry "Import-Module ActiveDirectory"
	
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
		localUser $userName $password
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------"
