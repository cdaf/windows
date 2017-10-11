# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; emailAndExit 1 }
	} catch { echo $_.Exception|format-list -force; emailAndExit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; emailAndExit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
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

if ((gwmi win32_computersystem).partofdomain -eq $true) {

	Write-Host "`n[$scriptName] Remove the new user`n"
	executeExpression  "Remove-ADUser -Name $userName"

} else {

	Write-Host "`n[$scriptName] Workgroup Host, delete local user ($userName).`n"
	$ADSIComp = executeExpression "[ADSI]`"WinNT://$Env:COMPUTERNAME,Computer`""
	executeExpression "`$ADSIComp.Delete('User', `"$userName`")"

}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
exit 0