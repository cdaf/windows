function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
}

$scriptName = 'newUser.ps1'
Write-Host
Write-Host "[$scriptName] New User on Domain or Workgroup, Windows Server 2012 and above"
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

if ((gwmi win32_computersystem).partofdomain -eq $true) {

	Write-Host
	Write-Host "[$scriptName] Add the new user, enabled with password"
	Write-Host
	executeExpression  "New-ADUser -Name $userName -AccountPassword (ConvertTo-SecureString -AsPlainText `$password -Force) -PassThru | Enable-ADAccount"

} else {

	Write-Host
	Write-Host "[$scriptName] Workgroup Host, create as local user ($userName)."
	$Computer = [ADSI]"WinNT://$Env:COMPUTERNAME,Computer"
	$LocalUser = $Computer.Create("User", $userName)
	$LocalUser.SetPassword($password)
	$LocalUser.SetInfo()
	$LocalUser.FullName = "$userName"
	$LocalUser.SetInfo()

}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
