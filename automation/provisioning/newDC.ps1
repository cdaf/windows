$scriptName = 'DC.ps1'
Write-Host
Write-Host "[$scriptName] New Domain Controller to existing Forest, Windows Server 2012 and above"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$forest = $args[0]
if ($forest) {
    Write-Host "[$scriptName] forest : $forest"
} else {
	$forest = 'sky.net'
    Write-Host "[$scriptName] forest : $forest (default)"
}

$password = $args[1]
if ($password) {
    Write-Host "[$scriptName] password : ********** "
} else {
	$password = 'Puwreyu5Asegucacr6za'
    Write-Host "[$scriptName] password : ********** (default)"
}

Write-Host "[$scriptName] Install the Active Directory Domain Services role"
Write-Host "[$scriptName]   Get-WindowsFeature AD-Domain-Services | Install-WindowsFeature"
Get-WindowsFeature AD-Domain-Services | Install-WindowsFeature

$securePassword = ConvertTo-SecureString $password -asplaintext -force

# Diagnostic helpers
# Test-ADDSForestInstallation -DomainName $forest -SafeModeAdministratorPassword $securePassword
# Test-ADDSDomainInstallation -NewDomainName $forest -ParentDomainName 'sky.net' -SafeModeAdministratorPassword $securePassword
# Test-ADDSDomainControllerInstallation -DomainName $forest -SafeModeAdministratorPassword $securePassword

Import-Module ADDSDeployment
Install-ADDSDomainController `
	-NoGlobalCatalog:$false `
	-InstallDns:$false `
	-CreateDnsDelegation:$false `
	-CriticalReplicationOnly:$false `
	-DatabasePath "C:\Windows\NTDS" `
	-LogPath "C:\Windows\NTDS" `
	-SysvolPath "C:\Windows\SYSVOL" `
	-DomainName $forest `
	-NoRebootOnCompletion:$false `
	-SiteName 'vagrant' `
	-Force:$true `
	-SafeModeAdministratorPassword $securePassword

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
