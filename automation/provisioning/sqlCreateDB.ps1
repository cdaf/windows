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

$dbOwner = $args[1]
if ($dbOwner) {
    Write-Host "[$scriptName] dbOwner    : $dbOwner"
} else {
    Write-Host "[$scriptName] dbOwner    : (not supplied)"
}

$dbhost = $args[2]
if ($dbhost) {
    Write-Host "[$scriptName] dbhost     : $dbhost"
} else {
	$dbhost = '.'
    Write-Host "[$scriptName] dbhost     : $dbhost (default)"
}

Write-Host
# Load the assemblies
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")'
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")'

Write-Host
$srv = executeExpression "new-Object Microsoft.SqlServer.Management.Smo.Server(`"$dbhost`")"
if ( $srv ) {
	executeExpression "`$srv | select Urn"
} else {
    Write-Host "[$scriptName] Server $dbhost not found!, Exit with code 103"; exit 103
}

Write-Host

$db = executeExpression "New-Object Microsoft.SqlServer.Management.Smo.Database(`$srv, `"$dbName`")"
executeExpression "`$db | select name"
executeExpression "`$db.Create()"
if ($dbOwner) {
	if ($dbOwner -eq $env:UserName) {
	    Write-Host "[$scriptName] Requested owner is current user, no action taken."
	} else {
		executeExpression "`$db.SetOwner(`"$dbOwner`", `$True)"
	}
}

Write-Host
executeExpression "`$srv.databases | select name"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
