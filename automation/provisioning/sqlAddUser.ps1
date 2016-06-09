# Load the assemblies
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")

$scriptName = 'sqlAddUser.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$dbUser = $args[0]
if ($dbUser) {
    Write-Host "[$scriptName] dbUser     : $dbUser"
} else {
    Write-Host "[$scriptName] dbUser not supplied, exiting with code 101"
    exit 101
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

	Write-Host; Write-Host "[$scriptName] User Add failed with exception, message follows ..."; Write-Host 
	Write-Host "[$scriptName] $_"; Write-Host 
	exit 2
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
