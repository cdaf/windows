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

$scriptName = 'sqlSetUserRole.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$dbUser = $args[0]
if ($dbUser) {
    Write-Host "[$scriptName] dbUser : $dbUser"
} else {
    Write-Host "[$scriptName] dbUser not supplied, exiting with code 101"; exit 101
}

$dbRole = $args[1]
if ($dbRole) {
    Write-Host "[$scriptName] dbRole : $dbRole"
} else {
    Write-Host "[$scriptName] dbRole not supplied, exiting with code 102"; exit 102
}

$dbhost = $args[2]
if ($dbhost) {
    Write-Host "[$scriptName] dbhost : $dbhost"
} else {
	$dbhost = '.'
    Write-Host "[$scriptName] dbhost : $dbhost (default)"
}

Write-Host
# Load the assemblies
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")'
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")'

# Rely on caller passing host or host\instance as they desire
$srv = new-Object Microsoft.SqlServer.Management.Smo.Server("$dbhost")

try {

	$SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $srv,"$dbUser"
	$dbrole = $srv.Roles[$dbRole]
	$dbrole.AddMember($adminUser)
	$dbrole.Alter()
	Write-Host; Write-Host "[$scriptName] User $dbUser added to role "; Write-Host 
	
} catch {

	Write-Host; Write-Host "[$scriptName] User Add failed with exception, message follows ..."; Write-Host 
	Write-Host "[$scriptName] $_"; Write-Host 
	exit 2
}

Write-Host
executeExpression '$dbrole.EnumMemberNames()'

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
