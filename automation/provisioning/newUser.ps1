$scriptName = 'newUser.ps1'
Write-Host
Write-Host "[$scriptName] New User on Domain, Windows Server 2012 and above"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$userName = $args[0]
if ($userName) {
    Write-Host "[$scriptName] userName          : $userName"
} else {
	$userName = 'Deployer'
    Write-Host "[$scriptName] userName          : $userName (default)"
}

$password = $args[1]
if ($password) {
    Write-Host "[$scriptName] password          : **********"
} else {
	$password = 'swUwe5aG'
    Write-Host "[$scriptName] password          : ********** (default)"
}

Write-Host "[$scriptName] Add the new user, enabled with password"
Write-Host "[$scriptName]   New-ADUser -Name $userName"

Write-Host
Write-Host "[$scriptName]   New-ADUser -Name $userName -AccountPassword (ConvertTo-SecureString -AsPlainText `$password -Force) -PassThru | Enable-ADAccount"
New-ADUser -Name $userName -AccountPassword (ConvertTo-SecureString -AsPlainText $password -Force) -PassThru | Enable-ADAccount

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
