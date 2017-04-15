# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	Add-Content "$imageLog" "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; Add-Content "$imageLog" "[$scriptName] `$? = $?"; emailAndExit 1 }
	} catch { echo $_.Exception|format-list -force; Add-Content "$imageLog" "$_.Exception|format-list"; emailAndExit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; Add-Content "$imageLog" "[$scriptName] `$error[0] = $error"; emailAndExit 3 }
    return $output
}

$scriptName = 'removeUser.ps1'
Write-Host "`n[$scriptName] Remove User from Domain or Workgroup, Windows Server 2012 and above`n"
Write-Host "`n[$scriptName] ---------- start ----------"
$userName = $args[0]
if ($userName) {
    Write-Host "[$scriptName] userName             : $userName"
} else {
	$userName = 'vagrant'
    Write-Host "[$scriptName] userName             : $userName (default)"
}
# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $userName`""
}

if ((gwmi win32_computersystem).partofdomain -eq $true) {

	Write-Host
	Write-Host "[$scriptName] Remove the new user"
	Write-Host
	executeExpression  "Remove-ADUser -Name $userName"

} else {

	Write-Host
	Write-Host "[$scriptName] Workgroup Host, delete local user ($userName)."
	$ADSIComp = executeExpression "[ADSI]`"WinNT://$Env:COMPUTERNAME,Computer`""
	executeExpression "`$ADSIComp.Delete('User', `"$userName`")"

}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
exit 0