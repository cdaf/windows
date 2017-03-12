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

$scriptName = 'SQLServer.ps1'
Write-Host
Write-Host "If provisioing to server core, the management console is not installed, for GUI server,"
Write-Host "Management console will be installed."
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

$EditionId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'EditionID').EditionId
if (($EditionId -like "*nano*") -or ($EditionId -like "*core*") ) {
	$noGUI = '(no GUI)'
}
write-host "[$scriptName] EditionId      : $EditionId $noGUI"

if ($env:interactive) {
	Write-Host
    Write-Host "[$scriptName]   env:interactive is set ($env:interactive), run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
	$logToConsole = 'true'
} else {
    $sessionControl = '-PassThru -Wait'
	$logToConsole = 'false'
}

if ($noGUI) {
    Write-Host "[$scriptName]   O/S GUI not installed, management tools will be excluded"
	$sqlFeatures = 'SQL'
} else {	
    Write-Host "[$scriptName]   O/S GUI installed, management tools will be included"
	$sqlFeatures = 'SQL,Tools'
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
	"/SQLSVCPASSWORD=`"$password`"",
	"/SQLSYSADMINACCOUNTS=`"$adminAccount`"",
	'/TCPENABLED=1',
	'/NPENABLED=1'
)
Write-Host
executeExpression "`$proc = Start-Process -FilePath `"$media$executable`" -ArgumentList `'$argList`' $sessionControl"

foreach ( $sqlVersions in Get-ChildItem "C:\Program Files\Microsoft SQL Server\" ) {
	$logPath = $sqlVersions.FullName + '\Setup Bootstrap\Log\Summary.txt'
	if ( Test-Path $logPath ) {
		$result = cat $logPath | findstr "Failed:"
		if ($result) {
			Write-Host
		    Write-Host "[$scriptName] `'Failed:`' found in $logPath, first 40 lines follow ..."
			Get-Content $logPath | select -First 40
		}
	} 
}


Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
