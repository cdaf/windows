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
		Invoke-Expression "$expression 2> `$null"
	    if(!$?) { Write-Error "[$scriptName][FAULT] `$? = $?"; $error ; exit 1111 }
	} catch {
		Write-Error "[$scriptName][EXCEPTION] List exception and error array (if populated) and exit with LASTEXITCIDE 1112" -ForegroundColor Red
		Write-Error $_.Exception|format-list -force
		if ( $error ) { Write-Error "[$scriptName][EXCEPTION] `$Error = $Error" ; $Error.clear() }
		exit 1112
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Error "[$scriptName][EXIT] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red
			if ( $error ) { Write-Error "[$scriptName][EXIT] `$Error = $Error" ; $Error.clear() }
			exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				Write-Host "[$scriptName][WARN] `$Error = $Error" ; $Error.clear()
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				Write-Error "[$scriptName][ERROR] `$Error = $error"; $Error.clear()
				Write-Error "[$scriptName][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting with LASTEXITCODE 1113 ..."; exit 1113
	    	} else {
		    	Write-Host "[$scriptName][WARN] `$Error = $error" ; $Error.clear()
	    	}
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