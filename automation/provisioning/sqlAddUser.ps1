Param (
  [string]$dbUser,
  [string]$dbhost,
  [string]$loginType,
  [string]$sqlPassword
)
$scriptName = 'sqlAddUser.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

Write-Host
Write-Host "[$scriptName] ---------- start ----------"
if ($dbUser) {
    Write-Host "[$scriptName] dbUser      : $dbUser"
} else {
    Write-Host "[$scriptName] dbUser not supplied, exiting with code 101"; exit 101
}

if ($dbhost) {
    Write-Host "[$scriptName] dbhost      : $dbhost"
} else {
	$dbhost = '.'
    Write-Host "[$scriptName] dbhost      : $dbhost (default)"
}

if ($loginType) {
    Write-Host "[$scriptName] loginType   : $loginType"
} else {
	$loginType = 'WindowsUser'
    Write-Host "[$scriptName] loginType   : $loginType (not supplied, set to default)"
}

if ($sqlPassword) {
    Write-Host "[$scriptName] sqlPassword : *********************** (only applicable if loginType is SQLLogin)"
} else {
	if ( $loginType -eq 'SQLLogin' ) {
    	Write-Host "[$scriptName] sqlPassword : not supplied, required when loginType is SQLLogin, exiting with code 102."; exit 102
	} else {
	    Write-Host "[$scriptName] sqlPassword : not supplied (only applicable if loginType is SQLLogin)"
    }
}

Write-Host "`n[$scriptName] Load the assemblies ...`n"
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")'
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")'

Write-Host
# Rely on caller passing host or host\instance as they desire
Write-Host "`n[$scriptName] Connect to SQL Server Instance ($dbhost) ...`n"
$srv = executeExpression "new-Object Microsoft.SqlServer.Management.Smo.Server(`"$dbhost`")"
if ( $srv ) {
	Write-Host "`n[$scriptName] List currentl Logins for SQL Server Instance ($dbhost) ...`n"
	executeExpression "`$srv.Logins | Format-Table -Property Name"
} else {
    Write-Host "[$scriptName] Server $dbhost not found!, Exit with code 103"; exit 103
}

Write-Host "`n[$scriptName] Create login for ($dbUser) ...`n"
$SqlUser = executeExpression "New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList `$srv,`"$dbUser`""
executeExpression "`$SqlUser | select Urn"

executeExpression "`$SqlUser.LoginType = `"$loginType`""
executeExpression "`$sqlUser.PasswordPolicyEnforced = `$False"
if ( $sqlPassword ) {
	executeExpression "`$SqlUser.Create(`$sqlPassword)"
} else {
	executeExpression "`$SqlUser.Create()"
}

Write-Host; Write-Host "`n[$scriptName] Login $dbUser added to $dbhost, listing all Logins after update ...`n"
executeExpression "`$srv.Logins | Format-Table -Property Name"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
