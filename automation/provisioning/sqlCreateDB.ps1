# Load the assemblies
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")

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
	$dbinstance = 'SQLSERVER'
    Write-Host "[$scriptName] dbinstance : $dbinstance (default)"
}

try {
	$srv = new-Object Microsoft.SqlServer.Management.Smo.Server("$dbhost\$dbinstance")
	$db = New-Object Microsoft.SqlServer.Management.Smo.Database($srv, $dbName)
	$db.Create()
	
} catch {

	Write-Host; Write-Host "[$scriptName] DB Create failed with exception, message follows ..."; Write-Host 
	Write-Host "[$scriptName] $_"; Write-Host 
	exit 2
}

$createdDate = $($db.CreateDate)
Write-Host
Write-Host "[$scriptName] Created $dbName on $dbhost\$dbinstance at $createdDate."

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
