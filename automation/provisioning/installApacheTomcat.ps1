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

$scriptName = 'installApacheTomcat.ps1'

Write-Host
Write-Host "[$scriptName] Requires 32-bit/64-bit Windows Service Installer"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
Write-Host

$tomcat_version = $args[0]
if ( $tomcat_version ) {
	Write-Host "[$scriptName] tomcat_version        : $tomcat_version"
} else {
	$tomcat_version = '8.5.4'
	Write-Host "[$scriptName] tomcat_version        : $tomcat_version (default)"
}

$sourceInstallDir = $args[1]
if ( $sourceInstallDir ) {
	Write-Host "[$scriptName] sourceInstallDir      : $sourceInstallDir"
} else {
	$sourceInstallDir = 'C:\.provision'
	Write-Host "[$scriptName] sourceInstallDir      : $sourceInstallDir (default)"
}

$destinationInstallDir = $args[2]
if ( $destinationInstallDir ) {
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir"
} else {
	$destinationInstallDir = 'C:\apache'
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir (default)"
}

# Cannot run interactive via remote PowerShell
if ($env:interactive) {
    Write-Host "[$scriptName] env:interactive : $env:interactive, run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
} else {
    $sessionControl = '-PassThru -Wait'
}

$tomcatServiceName = 'tomcat8'
$tomcatHomeDir = "$destinationInstallDir\apache-${tomcatServiceName}-${tomcat_version}"

# Create the installation directory for Tomcat
if ( Test-Path $tomcatHomeDir ) {
	Write-Host "[$scriptName] Destination folder ($tomcatHomeDir) exists, no action required"  -foregroundcolor Yellow
} else {
	try {
		New-Item -path $tomcatHomeDir -type directory
	} catch {
		Write-Host "CREATE_DESTINATION_DIRECTORY_EXCEPTION"
		echo $_.Exception|format-list -force
		exit 1
	}
}		
Write-Host
# Install Tomcat as a Windows Service
$apacheTomcatInstallFileName="apache-tomcat-" + $tomcat_version + ".exe";
if ( Test-Path $sourceInstallDir\$apacheTomcatInstallFileName ) {
	Write-Host "[$scriptName] Installing Tomcat as Windows Service ..."
	try {
		executeExpression "`$process = Start-Process `'$sourceInstallDir\$apacheTomcatInstallFileName`' -ArgumentList `'/S /D=$tomcatHomeDir`' $sessionControl"
		executeExpression "`$process = Start-Process `'$tomcatHomeDir\bin\Tomcat8.exe`' -ArgumentList `'//US//$tomcatServiceName --Startup=Auto`' $sessionControl"
	} catch {
		Write-Host "INSTALL_EXCEPTION"
		echo $_.Exception|format-list -force
		exit 2
	}
} else {
	Write-Host "[$scriptName] Install file ($sourceInstallDir\$apacheTomcatInstallFileName) not found!" -foregroundcolor Red
	exit 3
}	
			
Write-Host
executeExpression "[System.Environment]::SetEnvironmentVariable(`'CATALINA_HOME`', `'$tomcatHomeDir`', `'Machine`')"

Write-Host
$pathEnvVar=[System.Environment]::GetEnvironmentVariable("PATH","Machine")
executeExpression "[System.Environment]::SetEnvironmentVariable(`'PATH`', `'$pathEnvVar`' + `';$tomcatHomeDir\bin`', `'Machine`')"

Write-Host
try {
	Write-Host "[$scriptName] `$service = Start-Service `"$tomcatServiceName`" -PassThru"
 	$service = Start-Service "$tomcatServiceName" -PassThru
 	if ($service.status -ine 'Running') {
 		Write-Host "[$scriptName] Could not start service $tomcatServiceName" -foregroundcolor Red
		exit 4
 	} else {
		Write-Host "[$scriptName] $tomcatServiceName Service status = $service.status"
 	}			
} catch {
	Write-Host "START_EXCEPTION"
	echo $_.Exception|format-list -force
	exit 5
}		

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host
