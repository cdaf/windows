function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
}

$scriptName = 'SQLServer.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$serviceAccount = $args[0]
if ($serviceAccount) {
    Write-Host "[$scriptName] serviceAccount : $serviceAccount"
} else {
	$serviceAccount = 'sqlServiceAccount'
    Write-Host "[$scriptName] serviceAccount : $serviceAccount (default)"
}

$password = $args[1]
if ($password) {
    Write-Host "[$scriptName] password       : **********"
} else {
	$password = 'password'
    Write-Host "[$scriptName] password       : ********** (default)"
}

$adminAccount = $args[2]
if ($adminAccount) {
    Write-Host "[$scriptName] adminAccount   : $adminAccount"
} else {
	$adminAccount = 'BUILTIN\Administrators'
    Write-Host "[$scriptName] adminAccount   : $adminAccount (default)"
}

$instance = $args[3]
if ($instance) {
    Write-Host "[$scriptName] instance       : $instance"
} else {
	$instance = 'MSSQLSERVER'
    Write-Host "[$scriptName] instance       : $instance (default)"
}

$media = $args[4]
if ($media) {
    Write-Host "[$scriptName] media          : $media"
} else {
	$media = 'D:\'
    Write-Host "[$scriptName] media          : $media (default)"
}

if ($env:interactive) {
	Write-Host
    Write-Host "[$scriptName]   env:interactive is set ($env:interactive), run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
	$logToConsole = 'true'
} else {
    $sessionControl = '-PassThru -Wait'
	$logToConsole = 'false'
}

$gui = (Get-WindowsFeature -Name 'Server-Gui-Shell').Installed
if ($gui) {
    Write-Host "[$scriptName]   O/S GUI installed, management tools will be included"
	$sqlFeatures = 'SQL,Tools'
} else {	
    Write-Host "[$scriptName]   O/S GUI not installed, management tools will be excluded"
	$sqlFeatures = 'SQL'
}

$executable = Get-ChildItem d:\ -Filter *.exe

# Reference: https://msdn.microsoft.com/en-us/library/ms144259.aspx
$argList = @(
	'/Q',
	'/ACTION="Install"',
	"/INDICATEPROGRESS=$logToConsole",
	'/IACCEPTSQLSERVERLICENSETERMS',
	'/ENU=true',
	'/UPDATEENABLED=false',
	"/FEATURES=$sqlFeatures",
	'/INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"',
	"/INSTANCENAME=`"$instance`"",
	'/INSTANCEDIR="C:\Program Files\Microsoft SQL Server"',
	'/SQLSVCSTARTUPTYPE="Automatic"',
	'/SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS"',
	"/SQLSVCACCOUNT=`"$serviceAccount`"",
	"/SQLSVCPASSWORD=$password",
	"/SQLSYSADMINACCOUNTS=`"$adminAccount`"",
	'/TCPENABLED=1',
	'/NPENABLED=1'
)
Write-Host
executeExpression "`$proc = Start-Process -FilePath `"$media$executable`" -ArgumentList `'$argList`' $sessionControl"
Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
