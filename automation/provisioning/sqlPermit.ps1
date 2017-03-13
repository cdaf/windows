# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
}

$scriptName = 'sqlPermit.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$dbName = $args[0]
if ($dbName) {
    Write-Host "[$scriptName] dbName        : $dbName"
} else {
    Write-Host "[$scriptName] dbName not supplied, exiting with code 100"
    exit 100
}

$dbUser = $args[1]
if ($dbUser) {
    Write-Host "[$scriptName] dbUser       : $dbUser"
} else {
    Write-Host "[$scriptName] dbUser not supplied, exiting with code 101"
	exit 101
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

Write-Host
# Load the assemblies
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")'
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")'

# Rely on caller passing host or host\instance as they desire
$srv = new-Object Microsoft.SqlServer.Management.Smo.Server("$dbhost")

try {

	$db = $srv.Databases[$dbName]
	$dbRole = $db.Roles[$dbPermission]
	$dbRole.AddMember($dbUser)
	$dbRole.Alter()

	Write-Host; Write-Host "[$scriptName] Permission $dbPermission applied for user $dbUser to database $dbName"; Write-Host 

} catch {

	Write-Host; Write-Host "[$scriptName] DB exception, message follows ..."; Write-Host 
	Write-Host "[$scriptName] $_"; Write-Host 
	exit 2
}

Write-Host
executeExpression '$dbrole | select name'

Write-Host
$dbUser.EnumDatabaseMappings()

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
