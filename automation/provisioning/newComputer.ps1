Param (
  [string]$forest,
  [string]$newComputerName,
  [string]$domainAdminUser,
  [string]$domainAdminPass
)
$scriptName = 'newComputer.ps1'

Write-Host "`n[$scriptName] New Computer on Domain, Windows Server 2012 and above"
Write-Host "`n[$scriptName] ---------- start ----------"
if ($forest) {
    Write-Host "[$scriptName] forest          : $forest"
} else {
	$forest = 'sky.net'
    Write-Host "[$scriptName] forest          : $forest (default)"
}

if ($newComputerName) {
    Write-Host "[$scriptName] newComputerName : $newComputerName"
} else {
    Write-Host "[$scriptName] newComputerName : (not supplied, will add as $newComputerName)"
}

if ($domainAdminUser) {
    Write-Host "[$scriptName] domainAdminUser : $domainAdminUser"
} else {
	$domainAdminUser = 'vagrant'
    Write-Host "[$scriptName] domainAdminUser : $domainAdminUser (default)"
}

if ($domainAdminPass) {
    Write-Host "[$scriptName] domainAdminPass : **********"
} else {
	$domainAdminPass = 'vagrant'
    Write-Host "[$scriptName] domainAdminPass : ********** (default)"
}
# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $forest $newComputerName $domainAdminUser `'**********`' `""
}

$securePassword = ConvertTo-SecureString $domainAdminPass -asplaintext -force
$cred = New-Object System.Management.Automation.PSCredential ($domainAdminUser, $securePassword)

Write-Host "[$scriptName] Add this computer ($(hostname)) as $newComputerName to the domain"
if ($newComputerName) {
	Write-Host "[$scriptName] Add-Computer -DomainName $forest $newName -Passthru -Verbose -Credential `$cred"
} else {
	Write-Host "[$scriptName] Add-Computer -DomainName $forest -Passthru -Verbose -Credential `$cred"
}
	
$wait = 10
$retryMax = 3
$retryCount = 0
while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
	$exitCode = 0
	$error.clear()
	try {
		if ($newComputerName) {
			Add-Computer -DomainName $forest -NewName $newComputerName -Passthru -Verbose -Credential $cred
		} else {
			Add-Computer -DomainName $forest -Passthru -Verbose -Credential $cred
		}
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
	} catch { echo $_.Exception|format-list -force; $exitCode = 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; $exitCode = 3 }
    if ( $lastExitCode -ne 0 ) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode "; $exitCode = $lastExitCode }
    if ($exitCode -ne 0) {
		if ($retryCount -ge $retryMax ) {
			Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with code $exitCode"; exit $exitCode
		} else {
			$retryCount += 1
			Write-Host "[$scriptName] Attempt to remove the machine, pause $wait seocnds and retry"
			Remove-Computer -DomainName $forest -Passthru -Verbose -Credential $cred
			sleep $wait
		}
	}
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
