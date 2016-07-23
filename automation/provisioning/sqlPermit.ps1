# Load the assemblies
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")

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

$dbinstance = $args[4]
if ($dbinstance) {
    Write-Host "[$scriptName] dbinstance : $dbinstance"
	$smo = new-Object Microsoft.SqlServer.Management.Smo.Server("$dbhost\$dbinstance")
} else {
    Write-Host "[$scriptName] dbinstance : not supplied, let SQL Server decide"
	$smo = new-Object Microsoft.SqlServer.Management.Smo.Server("$dbhost")
}

try {

	$SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $smo,"$dbUser"
	$SqlUser.LoginType = 'WindowsUser'
	$sqlUser.PasswordPolicyEnforced = $false
	$SqlUser.Create()
	Write-Host; Write-Host "[$scriptName] User $dbUser added to $dbhost\$dbinstance"; Write-Host 

} catch {

	Write-Host; Write-Host "[$scriptName] DB exception, message follows ..."; Write-Host 
	Write-Host "[$scriptName] $_"; Write-Host 
	exit 2
}

$createdDate = $($db.CreateDate)
Write-Host
Write-Host "[$scriptName] Created $dbName on $dbhost\$dbinstance at $createdDate."

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
