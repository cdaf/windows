function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	# Execute expression and trap powershell exceptions
	try {
	    Invoke-Expression $expression
	    if(!$?) {
			Write-Host; Write-Host "[$scriptName] Expression failed without an exception thrown. Exit with code 1."; Write-Host 
			exit 1
		}
	} catch {
		Write-Host; Write-Host "[$scriptName] Expression threw exception. Exit with code 2, exception message follows ..."; Write-Host 
		Write-Host "[$scriptName] $_"; Write-Host 
		exit 2
	}
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
