Param (
	[string]$serviceAccount,
	[string]$adminAccount,
	[string]$instance,
	[string]$media,
	[string]$features,
	[string]$password
)
$scriptName = 'SQLServer.ps1'

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

# SQL Server 2012 and above.
Write-Host "`n[$scriptName] ---------- start ----------"
if ($serviceAccount) {
    Write-Host "[$scriptName] serviceAccount : $serviceAccount"
} else {
	$serviceAccount = 'sqlServiceAccount'
    Write-Host "[$scriptName] serviceAccount : $serviceAccount (default)"
}

if ($adminAccount) {
    Write-Host "[$scriptName] adminAccount   : $adminAccount"
} else {
	$adminAccount = 'BUILTIN\Administrators'
    Write-Host "[$scriptName] adminAccount   : $adminAccount (default)"
}

if ($instance) {
    Write-Host "[$scriptName] instance       : $instance"
} else {
	$instance = 'MSSQLSERVER'
    Write-Host "[$scriptName] instance       : $instance (default)"
}

if ($media) {
	if ($media -like '*$*') {
		if ($media -like '$env:*') {
			$varName = $media.Split(":")
			$loadedValue = Invoke-Expression "[Environment]::GetEnvironmentVariable(`"$($varName[1])`", `'User`')"
			if ($loadedValue) {
			    Write-Host "[$scriptName] loadedValue    : $loadedValue (from $media as user variable)"
				$media = $loadedValue
		    } else {
				$loadedValue = Invoke-Expression "[Environment]::GetEnvironmentVariable(`"$($varName[1])`", `'Machine`')"
				if ($loadedValue) {
				    Write-Host "[$scriptName] loadedValue    : $loadedValue (from $media as machine variable)"
					$media = $loadedValue
				} else {
				    Write-Host "`n[$scriptName] Unable to resolve $media, exit with LASTEXITCODE=10"; exit 10
				}
			}
		} else {
		    $media = Invoke-Expression "Write-Output $media" # Evaluate in case a session variable has been passed, i.e. $loadedVarable:\
		    Write-Host "[$scriptName] media          : $media (evaluated)"
	    }
    }
    Write-Host "[$scriptName] media          : $media"
} else {
	$media = 'D:\'
    Write-Host "[$scriptName] media          : $media (default)"
}

if ($features) { # https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-on-server-core#a-namebksupportedfeaturesa-supported-features
    Write-Host "[$scriptName] features       : $features"
} else {
	$features = 'SQLEngine,FullText,Conn'
    Write-Host "[$scriptName] features       : $features (default)"
}

if ($password) {
    Write-Host "[$scriptName] password       : `$password"
} else {
    Write-Host "[$scriptName] password       : (not supplied, assuming managed service account)"
}

$EditionId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'EditionID').EditionId
write-host "[$scriptName] EditionId      : $EditionId"

if ($env:interactive) {
	Write-Host
    Write-Host "[$scriptName]   env:interactive is set ($env:interactive), run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
	$logToConsole = 'true'
} else {
    $sessionControl = '-PassThru -Wait'
	$logToConsole = 'false'
}

$executable = Get-ChildItem $media -Filter *.exe

if ( $password ) {
	# Reference: https://msdn.microsoft.com/en-us/library/ms144259.aspx
	# Argument list initially loaded for logging purposes only ...
	$argList = @(
		'/Q',
		'/ACTION="Install"',
		"/INDICATEPROGRESS=$logToConsole",
		'/IACCEPTSQLSERVERLICENSETERMS',
		'/ENU=true',
		'/UPDATEENABLED=false',
		"/FEATURES=$features",
		'/INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"',
		"/INSTANCENAME=`"$instance`"",
		'/INSTANCEDIR="C:\Program Files\Microsoft SQL Server"',
		'/SQLSVCSTARTUPTYPE="Automatic"',
		'/SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS"',
		"/SQLSVCACCOUNT=`"$serviceAccount`"",
		"/SQLSVCPASSWORD=`"`$password`"",
		"/SQLSYSADMINACCOUNTS=`"$adminAccount`"",
		'/TCPENABLED=1',
		'/NPENABLED=1'
	)
	Write-Host "[$scriptName] `$proc = Start-Process -FilePath `"$media$executable`" -ArgumentList `"$argList`" $sessionControl"
	
	# ... reload the argument list to use the service account password
	$argList = @(
		'/Q',
		'/ACTION="Install"',
		"/INDICATEPROGRESS=$logToConsole",
		'/IACCEPTSQLSERVERLICENSETERMS',
		'/ENU=true',
		'/UPDATEENABLED=false',
		"/FEATURES=$features",
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
} else {
	$argList = @(
		'/Q',
		'/ACTION="Install"',
		"/INDICATEPROGRESS=$logToConsole",
		'/IACCEPTSQLSERVERLICENSETERMS',
		'/ENU=true',
		'/UPDATEENABLED=false',
		"/FEATURES=$features",
		'/INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"',
		"/INSTANCENAME=`"$instance`"",
		'/INSTANCEDIR="C:\Program Files\Microsoft SQL Server"',
		'/SQLSVCSTARTUPTYPE="Automatic"',
		'/SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS"',
		"/SQLSVCACCOUNT=`"$serviceAccount`"",
		"/SQLSYSADMINACCOUNTS=`"$adminAccount`"",
		'/TCPENABLED=1',
		'/NPENABLED=1'
	)
	Write-Host "[$scriptName] `$proc = Start-Process -FilePath `"$media$executable`" -ArgumentList `"$argList`" $sessionControl"
}

# Note, the actual call passes the argument list as a literal
$proc = executeExpression "Start-Process -FilePath `"$media$executable`" -ArgumentList `'$argList`' $sessionControl"

foreach ( $sqlVersions in Get-ChildItem "C:\Program Files\Microsoft SQL Server\" ) {
	$logPath = $sqlVersions.FullName + '\Setup Bootstrap\Log\Summary.txt'
	if ( Test-Path $logPath ) {
		$result = cat $logPath | findstr "Failed:"
		if ($result) {
		    Write-Host "`n[$scriptName] Process output ..."
			$proc | format-list 
		    
		    Write-Host "`n[$scriptName] `'Failed:`' found in $logPath, first 40 lines follow ..."
			Get-Content $logPath | select -First 40
		    Write-Host "`n[$scriptName] Exit with LASTEXITCODE = 20"; exit 20
		}
	} 
}

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0