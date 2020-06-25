Param (
	[string]$forest,
	[string]$domainAdminUser,
	[string]$domainAdminPass,
	[string]$domainController,
	[string]$delegateTo
)

cmd /c "exit 0"
$Error.Clear()

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1112 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red ; $error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE, $error[] = $error`n" -ForegroundColor Yellow
				$error.clear()
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName][WARN] $Error array populated but LASTEXITCODE not set, $error[] = $error`n" -ForegroundColor Yellow
			$error.clear()
		}
	}
}

$scriptName = 'addComputerDelegation.ps1'
Write-Host "`n[$scriptName] Allow a computer to delegate user credentials, combines with setSPN.ps1"
Write-Host "[$scriptName] If on the domain controller, use setSPN.ps1 computer <computerName>"
Write-Host "`n[$scriptName] ---------- start ----------"
if ($forest) {
    Write-Host "[$scriptName] forest           : $forest"
} else {
	$forest = 'mshome.net'
    Write-Host "[$scriptName] forest           : $forest (default)"
}

if ($domainAdminUser) {
    Write-Host "[$scriptName] domainAdminUser  : $domainAdminUser"
} else {
	$domainAdminUser = 'vagrant'
    Write-Host "[$scriptName] domainAdminUser  : $domainAdminUser (default)"
}

if ($domainAdminPass) {
    Write-Host "[$scriptName] domainAdminPass  : **********"
} else {
	$domainAdminPass = 'vagrant'
    Write-Host "[$scriptName] domainAdminPass  : ********** (default)"
}

if ($domainController) {
    Write-Host "[$scriptName] domainController : $domainController"
} else {
	$domainController = '172.16.17.98'
    Write-Host "[$scriptName] domainController : $domainController (default)"
}

if ($delegateTo) {
    Write-Host "[$scriptName] delegateTo       : $delegateTo"
} else {
    Write-Host "[$scriptName] delegateTo       : (not supplied)"
}

$securePassword = ConvertTo-SecureString $domainAdminPass -asplaintext -force
$cred = New-Object System.Management.Automation.PSCredential ($domainAdminUser, $securePassword)

Write-Host "`n[$scriptName] Set this computer ($(hostname)) delegation privileges on domain ($forest)"
executeExpression "Invoke-Command -ComputerName $domainController -Credential `$cred -ScriptBlock {
	Set-ADComputer -Identity '$env:COMPUTERNAME' -TrustedForDelegation `$True
} "

if ($delegateTo) {
	executeExpression "Invoke-Command -ComputerName $domainController -Credential `$cred -ScriptBlock {
		`$delegator = Get-ADComputer -Identity '$env:COMPUTERNAME'
		Set-ADComputer -Identity '$delegateTo' -PrincipalsAllowedToDelegateToAccount `$delegator
	} "
}
Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0