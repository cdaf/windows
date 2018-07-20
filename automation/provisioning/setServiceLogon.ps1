Param (
  [string]$userName
)
$scriptName = 'setServiceLogon.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($userName) {
    Write-Host "[$scriptName] userName          : $userName"
} else {
	$userName = $(whoami)
    Write-Host "[$scriptName] userName          : $userName (not passed, defaulted to current user)"
}

# Separate domain and uername
$userDomain,$userAlias = $userName.split('\')
if ( $userDomain -eq '.' ) {
	$userDomain = $env:COMPUTERNAME
}
Write-Host "[$scriptName] userDomain        : $userDomain"
Write-Host "[$scriptName] userAlias         : $userAlias"
$workingDirectory = $(pwd)
Write-Host "[$scriptName] $workingDirectory : $workingDirectory"

$scriptPath = (Get-Location).Path

$objUser = New-Object System.Security.Principal.NTAccount($userDomain, $userAlias)
$strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
$sid = $strSID.Value

Write-Host "User SID: $sid"

executeExpression "secedit /export /cfg c:\backup.txt"
$fileName = 'c:\backup.inf'
executeExpression "Copy-Item 'c:\backup.txt' '$fileName' -Force"
$token = foreach ( $line in Get-Content 'C:\backup.inf' ) { if ( $line -match 'SeServiceLogonRight' ) { $line } }
Write-Host "[$scriptName] token : $token"
if ( $token -match $sid ) {
	Write-Host "[$scriptName] User $userAlias already has login rights, no action attempted"; exit 0
}
$value = $token + ",*$sid"
Write-Host "[$scriptName] value : $value"
(Get-Content $fileName | ForEach-Object { $_ -replace [regex]::Escape($token), "$value" } ) | Set-Content $fileName

$seceditFile = "$env:SystemRoot\security\database\secedit.sdb"
write-host "Verify default database exists ($seceditFile)"
if((Test-Path $seceditFile) -eq $false)
{
    Write-Error "Security database does not exist $seceditFile"
}

write-host "Validating new security template file ($fileName)"
executeExpression "secedit /validate $fileName"
$exitcode = $LASTEXITCODE
if($exitcode -ne 0)
{
    Write-Error "Error in validating template file, $fileName exit code $exitcode"
    exit $exitcode
}

write-host "Apply configuration from user home directory to avoid 'access denied' issues"
executeExpression "cd ~"

write-host "Applying security template to default database ($seceditFile)"
executeExpression "secedit /configure /db secedit.sdb /cfg '$fileName'"
$exitcode = $LASTEXITCODE
if($exitcode -ne 0)
{
    Write-Error "Error in secedit call, exit code $exitcode`n"
    cat "$env:windir\security\logs\scesrv.log"
    exit $exitcode
}
write-host "Successfully granted log on as service access to user ${userAlias}, return to working dirctory" -ForegroundColor Green
executeExpression "cd $workingDirectory"

write-host "Reload Group Policy"
executeExpression "gpupdate /force"

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0
