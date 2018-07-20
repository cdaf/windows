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

$scriptName = 'sqlSetLoginRole.ps1'
Write-Host "`n[$scriptName] ---------- start ----------"
$loginName = $args[0]
if ($loginName) {
    Write-Host "[$scriptName] loginName : $loginName"
} else {
    Write-Host "[$scriptName] loginName not supplied, exiting with code 101"; exit 101
}

$dbRole = $args[1]
if ($dbRole) {
    Write-Host "[$scriptName] dbRole    : $dbRole"
} else {
    Write-Host "[$scriptName] dbRole not supplied, exiting with code 102"; exit 102
}

$dbhost = $args[2]
if ($dbhost) {
    Write-Host "[$scriptName] dbhost    : $dbhost"
} else {
	$dbhost = '.'
    Write-Host "[$scriptName] dbhost    : $dbhost (default)"
}

Write-Host "`n[$scriptName] Load the assemblies ...`n"
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")'
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")'

# Rely on caller passing host or host\instance as they desire
Write-Host "`n[$scriptName] Connect to the SQL Server instance ($dbhost) ..."
$srv = executeExpression "new-Object Microsoft.SqlServer.Management.Smo.Server(`'$dbhost`')"
if ( $srv ) {
	Write-Host "`n[$scriptName] List existing roles and members ...`n"
 	foreach ($role in $srv.roles) { $role.name; foreach ($member in $role.EnumMemberNames()) { Write-Host "  $member" } }
} else {
    Write-Host "[$scriptName] Server $dbhost not found!, Exit with code 103"; exit 103
}

try {

 	Write-Host
	$sqlLogin = executeExpression "New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList `$srv,`"$loginName`""
	Write-Host "`n[$scriptName] List the current user roles ...`n"
	if ( $sqlLogin ) {
		executeExpression "`$sqlLogin | select Urn"
	} else {
	    Write-Host "[$scriptName] SQL Server Login $sqlLogin not found!, Exit with code 104"; exit 104
	}
	
	$dbrole = executeExpression "`$srv.Roles[`"$dbRole`"]"
	if ( $dbrole ) {
		executeExpression "`$dbrole | select Urn"
	} else {
	    Write-Host "[$scriptName] Database Role $dbRole not found!, Exit with code 105"; exit 105
	}
	executeExpression "`$dbrole.AddMember(`"$loginName`")"
	executeExpression "`$dbrole.Alter()"
	Write-Host "`n[$scriptName] Login $loginName added to role $dbrole." 
	
} catch {

	Write-Host; Write-Host "[$scriptName] User Add failed with exception, message follows ..."; Write-Host 
	Write-Host "[$scriptName] $_"; Write-Host 
	exit 106
}

Write-Host "`n[$scriptName] List resulting roles and members ...`n"
foreach ($role in $srv.roles) { $role.name; foreach ($member in $role.EnumMemberNames()) { Write-Host "  $member" } }

Write-Host "`n[$scriptName] ---------- stop ----------"
