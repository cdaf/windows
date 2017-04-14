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

$scriptName = 'deleteLocalUser.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$userName = $args[0]
if ($userName) {
    Write-Host "[$scriptName] userName : $userName"
} else {
	$userName = 'Vagrant'
    Write-Host "[$scriptName] userName : $userName (default)"
}

Write-Host "`n[$scriptName] Delete $userName"
$ADSIComp = executeExpression "[ADSI]`"WinNT://$Env:COMPUTERNAME,Computer`""
executeExpression "$ADSIComp.Delete(`'User`', `"$userName`")"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
