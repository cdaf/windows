Param (
  [string]$dbName,
  [string]$dbUser,
  [string]$dbPermissions,
  [string]$dbhost
)

# Reset $LASTEXITCODE
cmd /c exit 0
$error.clear()

# Common expression logging and error handling function, copied, not referenced to ensure atomic processfunction executeExpression ($expression) {
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
	
$scriptName = 'sqlPermit.ps1'
Write-Host "`n[$scriptName] ---------- start ----------"
if ($dbName) {
    Write-Host "[$scriptName] dbName        : $dbName"
} else {
    Write-Host "[$scriptName] dbName not supplied, exiting with code 100"; exit 100
}

if ($dbUser) {
    Write-Host "[$scriptName] dbUser        : $dbUser"
} else {
    Write-Host "[$scriptName] dbUser not supplied, exiting with code 101"; exit 101
}

if ($dbPermissions) {
    Write-Host "[$scriptName] dbPermissions : $dbPermissions"
} else {
    Write-Host "[$scriptName] dbPermissions not supplied, available permissions will be listed"
}

if ($dbhost) {
    Write-Host "[$scriptName] dbhost        : $dbhost"
} else {
	$dbhost = '.'
    Write-Host "[$scriptName] dbhost        : $dbhost (default)"
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

if ($dbPermissions) {
	Write-Host "`n[$scriptName] List the current user roles ...`n"
	$usr = executeExpression "New-Object ('Microsoft.SqlServer.Management.Smo.User') (`$db, `"$dbUser`")"
	executeExpression "`$usr.EnumRoles()"

	foreach ($permissionName in $dbPermissions) {
		
		Write-Host "`n[$scriptName] List all users currently with this role ...`n"
		$dbRole = executeExpression "`$db.Roles[`"$permissionName`"]"
		if ( $dbRole ) {
			executeExpression "`$dbRole | select Urn"
			executeExpression "`$dbRole.EnumMembers()"
		} else {
		    Write-Host "[$scriptName] Database Role $dbPermissions not found!, Exit with code 105"; exit 105
		}
		
		executeExpression "`$dbRole.AddMember(`"$dbUser`")"
		executeExpression "`$dbRole.Alter()"
		
		Write-Host "`n[$scriptName] List all users with this role after update ...`n"
		executeExpression "`$dbrole.EnumMembers()"
		
		Write-Host "`n[$scriptName] List the user roles after update ...`n"
		executeExpression "`$usr.EnumRoles()"
	}
} else {
	Write-Host "`n[$scriptName] dbPermissions not passed, listing available permissions ...`n"
	foreach ($permission in $db.Roles) { $permission.Name }
}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
exit 0