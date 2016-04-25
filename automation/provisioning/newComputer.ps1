$scriptName = 'newComputer.ps1'
Write-Host
Write-Host "[$scriptName] New Computer on Domain, Windows Server 2012 and above"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$forest = $args[0]
if ($forest) {
    Write-Host "[$scriptName] forest          : $forest"
} else {
	$forest = 'sky.net'
    Write-Host "[$scriptName] forest          : $forest (default)"
}

$domainAdminUser = $args[1]
if ($domainAdminUser) {
    Write-Host "[$scriptName] domainAdminUser : **********"
} else {
	$domainAdminUser = 'vagrant'
    Write-Host "[$scriptName] domainAdminUser : ********** (default)"
}

$domainAdminPass = $args[1]
if ($domainAdminPass) {
    Write-Host "[$scriptName] domainAdminPass : **********"
} else {
	$domainAdminPass = 'vagrant'
    Write-Host "[$scriptName] domainAdminPass : ********** (default)"
}

$securePassword = ConvertTo-SecureString $domainAdminPass -asplaintext -force
$cred = New-Object System.Management.Automation.PSCredential ($domainAdminUser, $securePassword)

Write-Host "[$scriptName] Add this computer ($(hostname)) to the domain"
Write-Host "[$scriptName]   Add-Computer -DomainName $forest -Passthru -Verbose -Credential ********"
Add-Computer -DomainName $forest -Passthru -Verbose -Credential $cred

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
