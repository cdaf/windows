Param (
	[string]$userName
)

cmd /c "exit 0"
$Error.Clear()

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1112 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red ; $error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE, $error[] = $error`n" -ForegroundColor Yellow
				$error.clear()
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName][WARN] $Error array populated but LASTEXITCODE not set, $error[] = $error`n" -ForegroundColor Yellow
			$error.clear()
		}
	}
}

function removeLocal ($userName) {
	Write-Host "`n[$scriptName] Workgroup Host, delete local user ($userName).`n"
	$ADSIComp = executeExpression "[ADSI]`"WinNT://$Env:COMPUTERNAME,Computer`""
	executeExpression "`$ADSIComp.Delete('User', `"$userName`")"
	executeExpression "net user"
}

$scriptName = 'removeUser.ps1'
Write-Host "`n[$scriptName] Remove User from Domain or Workgroup, Windows Server 2012 and above. Pass .\ prefix for local user.`n"
Write-Host "`n[$scriptName] ---------- start ----------"
if ($userName) {
    Write-Host "[$scriptName] userName : $userName"
} else {
	$userName = 'vagrant'
    Write-Host "[$scriptName] userName : $userName (default)"
}

if ( $userName.StartsWith('.\')) { 

	$prefix, $userName = $userName.Split('\')
	removeLocal $userName

} else {

	if ((gwmi win32_computersystem).partofdomain -eq $true) {
	
		Write-Host "`n[$scriptName] Remove the new user`n"
		executeExpression  "Remove-ADUser -Name $userName"
	
	} else {
	
		removeLocal $userName
	
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
exit 0