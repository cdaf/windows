$scriptName = 'newForest.ps1'
Write-Host
Write-Host "[$scriptName] New Forest, Windows Server 2012 and above"
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

Install-ADDSForest -DomainName $forest -SafeModeAdministratorPassword $securePassword -Force

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
