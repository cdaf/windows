function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
}

$scriptName = 'removeUser.ps1'
Write-Host
Write-Host "[$scriptName] Remove User from Domain or Workgroup, Windows Server 2012 and above"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$userName = $args[0]
if ($userName) {
    Write-Host "[$scriptName] userName             : $userName"
} else {
	$userName = 'Deployer'
    Write-Host "[$scriptName] userName             : $userName (default)"
}

if ((gwmi win32_computersystem).partofdomain -eq $true) {

	Write-Host
	Write-Host "[$scriptName] Remove the new user"
	Write-Host
	executeExpression  "Remove-ADUser -Name $userName"

} else {

	Write-Host
	Write-Host "[$scriptName] Workgroup Host, delete local user ($userName)."
	$ADSIComp = [ADSI]"WinNT://$Env:COMPUTERNAME,Computer"
	$ADSIComp.Delete('User', $userName)

}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
