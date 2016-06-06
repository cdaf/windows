function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	# Execute expression and trap powershell exceptions
	try {
	    Invoke-Expression $expression
	    if(!$?) {
			Write-Host; Write-Host "[$scriptName] Expression failed without an exception thrown. Exit with code 1."; Write-Host 
			exit 1
		}
	} catch {
		Write-Host; Write-Host "[$scriptName] Expression threw exception. Exit with code 2, exception message follows ..."; Write-Host 
		Write-Host "[$scriptName] $_"; Write-Host 
		exit 2
	}
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
	$adminAccount = 'Administrator'
    Write-Host "[$scriptName] adminAccount   : $adminAccount (default)"
}

$media = $args[3]
if ($media) {
    Write-Host "[$scriptName] media          : $media"
} else {
	$media = 'D:\'
    Write-Host "[$scriptName] media          : $media (default)"
}

if ($env:interactive) {
	Write-Host
    Write-Host "[$scriptName] env:interactive is set ($env:interactive), run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
} else {
    $sessionControl = '-PassThru -Wait'
}

$executable = Get-ChildItem d:\ -Filter *.exe

# Reference: https://msdn.microsoft.com/en-us/library/ms144259.aspx
$argList = @(
	'/Q',
	'/ACTION="Install"',
#	'/INDICATEPROGRESS=true',
	'/IACCEPTSQLSERVERLICENSETERMS',
	'/ENU=true',
	'/UPDATEENABLED=true',
	'/FEATURES=SQL,Tools',
	'/INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"',
	'/INSTANCENAME="SQLSERVER"',
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
