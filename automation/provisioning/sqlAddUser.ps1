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

$domain = $args[1]
if ($domain) {
    Write-Host "[$scriptName] domain     : $domain"
} else {
	$domain = '.'
    Write-Host "[$scriptName] domain     : $domain (not supplied, default value set)"
}

$dbhost = $args[2]
if ($dbhost) {
    Write-Host "[$scriptName] dbhost     : $dbhost"
} else {
	$dbhost = '.'
    Write-Host "[$scriptName] dbhost     : $dbhost (default)"
}

$dbinstance = $args[3]
if ($dbinstance) {
    Write-Host "[$scriptName] dbinstance : $dbinstance"
} else {
    Write-Host "[$scriptName] dbinstance : not supplied, let SQL Server decide"
}

$loginType = $args[4]
if ($loginType) {
    Write-Host "[$scriptName] loginType  : $loginType"
} else {
	$loginType = 'WindowsUser'
    Write-Host "[$scriptName] loginType  : $loginType (not supplied, set to default)"
}

# Load the assemblies
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")'
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")'

if ($dbinstance) {
	$srv = new-Object Microsoft.SqlServer.Management.Smo.Server("$dbhost\$dbinstance")
} else {
	$srv = new-Object Microsoft.SqlServer.Management.Smo.Server("$dbhost")
}

try {

	$SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $srv,"$domain\$dbUser"
	$SqlUser.LoginType = $loginType
	$sqlUser.PasswordPolicyEnforced = $false
	$SqlUser.Create()
	Write-Host; Write-Host "[$scriptName] User $domain\$dbUser added to $dbhost\$dbinstance"; Write-Host 
	
} catch {

	Write-Host; Write-Host "[$scriptName] User Add failed with exception, message follows ..."; Write-Host 
	Write-Host "[$scriptName] $_"; Write-Host 
	exit 2
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
