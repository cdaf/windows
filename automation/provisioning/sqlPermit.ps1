# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    return $output
}

$scriptName = 'sqlPermit.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$dbName = $args[0]
if ($dbName) {
    Write-Host "[$scriptName] dbName       : $dbName"
} else {
    Write-Host "[$scriptName] dbName not supplied, exiting with code 100"; exit 100
}

$dbUser = $args[1]
if ($dbUser) {
    Write-Host "[$scriptName] dbUser       : $dbUser"
} else {
    Write-Host "[$scriptName] dbUser not supplied, exiting with code 101"; exit 101
}

$dbPermission = $args[2]
if ($dbPermission) {
    Write-Host "[$scriptName] dbPermission : $dbPermission"
} else {
    Write-Host "[$scriptName] dbPermission not supplied, exiting with code 102"
	exit 102
}

$dbhost = $args[3]
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

Write-Host "`n[$scriptName] Connect to the database ($dbName) ...`n"
$db = executeExpression "`$srv.Databases[`"$dbName`"]"
if ( $db ) {
	executeExpression "`$db | select Urn"
} else {
    Write-Host "[$scriptName] Database $dbName not found!, Exit with code 104"; exit 104
}

Write-Host "`n[$scriptName] List the current user roles ...`n"
$usr = executeExpression "New-Object ('Microsoft.SqlServer.Management.Smo.User') (`$db, `"$dbUser`")"
executeExpression "`$usr.EnumRoles()"

Write-Host "`n[$scriptName] List all users currently with this role ...`n"
$dbRole = executeExpression "`$db.Roles[`"$dbPermission`"]"
if ( $dbRole ) {
	executeExpression "`$dbRole | select Urn"
	executeExpression "`$dbRole.EnumMembers()"
} else {
    Write-Host "[$scriptName] Database Role $dbPermission not found!, Exit with code 105"; exit 105
}

executeExpression "`$dbRole.AddMember(`"$dbUser`")"
executeExpression "`$dbRole.Alter()"

Write-Host "`n[$scriptName] List all users with this role after update ...`n"
executeExpression "`$dbrole.EnumMembers()"

Write-Host "`n[$scriptName] List the user roles after update ...`n"
executeExpression "`$usr.EnumRoles()"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
