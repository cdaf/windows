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

$scriptName = 'sqlCreateDB.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$dbName = $args[0]
if ($dbName) {
    Write-Host "[$scriptName] dbName     : $dbName"
} else {
    Write-Host "[$scriptName] dbName not supplied, exiting with code 100"
    exit 100
}

$dbhost = $args[1]
if ($dbhost) {
    Write-Host "[$scriptName] dbhost     : $dbhost"
} else {
	$dbhost = '.'
    Write-Host "[$scriptName] dbhost     : $dbhost (default)"
}

$dbinstance = $args[2]
if ($dbinstance) {
    Write-Host "[$scriptName] dbinstance : $dbinstance"
} else {
    Write-Host "[$scriptName] dbinstance : not supplied, let SQL Server decide"
}

$dbOwner = $args[3]
if ($dbOwner) {
    Write-Host "[$scriptName] dbOwner    : $dbOwner"
} else {
    Write-Host "[$scriptName] dbOwner    : not supplied"
}

Write-Host
# Load the assemblies
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")'
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")'

Write-Host
if ($dbinstance) {
	Write-Host "[$scriptName] `$srv = new-Object Microsoft.SqlServer.Management.Smo.Server(`"$dbhost\$dbinstance`")"
	$srv = new-Object Microsoft.SqlServer.Management.Smo.Server("$dbhost\$dbinstance")
} else {
	Write-Host "[$scriptName] `$srv = new-Object Microsoft.SqlServer.Management.Smo.Server(`"$dbhost`")"
	$srv = new-Object Microsoft.SqlServer.Management.Smo.Server("$dbhost")
}

executeExpression '$srv.databases | select name'

Write-Host
try {

    Write-Host "[$scriptName] `$db = New-Object Microsoft.SqlServer.Management.Smo.Database($srv, $dbName)"
	$db = New-Object Microsoft.SqlServer.Management.Smo.Database($srv, $dbName)
    Write-Host "[$scriptName] `$db.Create()"
	$db.Create()
	if ($dbOwner) {
	    Write-Host "[$scriptName] `$db.SetOwner($dbOwner, `$TRUE)"
		$db.SetOwner($dbOwner, $TRUE)
	}
	
} catch {

	Write-Host; Write-Host "[$scriptName] DB Create failed with exception, message follows ..."; Write-Host 
	Write-Host "[$scriptName] $_"; Write-Host 
	exit 2
}

Write-Host
$createdDate = $($db.CreateDate)
Write-Host "[$scriptName] Created $dbName on $dbhost\$dbinstance at $createdDate."

Write-Host
executeExpression '$srv.databases | select name'

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
