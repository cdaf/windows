Param (
  [string]$dbName,
  [string]$dbUser,
  [string]$dbhost
)

# Reset $LASTEXITCODE
cmd /c exit 0

$scriptName = 'sqlAddUserDB.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($dbName) {
    Write-Host "[$scriptName] dbName       : $dbName"
} else {
    Write-Host "[$scriptName] dbName not supplied, exiting with code 100"; exit 100
}

if ($dbUser) {
    Write-Host "[$scriptName] dbUser       : $dbUser"
} else {
    Write-Host "[$scriptName] dbUser not supplied, exiting with code 101"; exit 101
}

if ($dbhost) {
    Write-Host "[$scriptName] dbhost       : $dbhost"
} else {
	$dbhost = '.'
    Write-Host "[$scriptName] dbhost       : $dbhost (default)"
}

Write-Host "`n[$scriptName] Load the assemblies ...`n"
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")'
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")'

# Rely on caller passing host or host\instance as they desire
Write-Host "`n[$scriptName] Connect to the SQL Server instance ($dbhost) ...`n"
$srv = executeExpression "new-Object Microsoft.SqlServer.Management.Smo.Server(`"$dbhost`")"
if ( $srv ) {
	executeExpression "`$srv | select Urn"
} else {
    Write-Host "[$scriptName] Server $dbhost not found!, Exit with code 103"; exit 103
}

Write-Host "`n[$scriptName] List current permissions for database ($dbName) ...`n"
$db = executeExpression "`$srv.Databases[`"$dbName`"]"
if ( $db ) {
	executeExpression "`$db | select Urn"
	executeExpression "`$db.EnumDatabasePermissions() | select Grantee, PermissionState"
} else {
    Write-Host "[$scriptName] Database $dbName not found!, Exit with code 104"; exit 104
}

Write-Host "`n[$scriptName] List user permission before update ...`n"
$usr = executeExpression "New-Object ('Microsoft.SqlServer.Management.Smo.User') (`$db, `"$dbUser`")"
if ( $usr ) {
	executeExpression "`$usr | select Urn"
	executeExpression "`$usr.EnumObjectPermissions()"
} else {
    Write-Host "[$scriptName] User $dbUser not found!, Exit with code 105"; exit 105
}
executeExpression "`$usr.Login = `$dbUser"
executeExpression "`$usr.Create()"

Write-Host "`n[$scriptName] List user and database permissions after update ...`n"
executeExpression "`$usr.EnumObjectPermissions()"
executeExpression "`$db.EnumDatabasePermissions() | select Grantee, PermissionState"

Write-Host "`n[$scriptName] ---------- stop ----------"
