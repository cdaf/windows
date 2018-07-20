Param (
	[string]$tomcat_version,
	[string]$sourceInstallDir,
	[string]$destinationInstallDir
)
$scriptName = 'installApacheTomcat.ps1'

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

Write-Host "`n[$scriptName] ---------- start ----------"

if ( $tomcat_version ) {
	Write-Host "[$scriptName] tomcat_version        : $tomcat_version"
} else {
	$tomcat_version = '8.5.32'
	$md5 = 'fce525887c4d60ab7b8871f4e85ef5906e61e62b'
	Write-Host "[$scriptName] tomcat_version        : $tomcat_version (default)"
}

if ( $sourceInstallDir ) {
	Write-Host "[$scriptName] sourceInstallDir      : $sourceInstallDir"
} else {
	$sourceInstallDir = 'C:\.provision'
	Write-Host "[$scriptName] sourceInstallDir      : $sourceInstallDir (default)"
}

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
$apacheTomcatInstallFileName = "apache-tomcat-" + $tomcat_version + ".exe";

if (!( Test-Path $sourceInstallDir\$apacheTomcatInstallFileName )) {
	# Create media cache if missing
	if (!( Test-Path $sourceInstallDir )) {
		Write-Host "[$scriptName] Created $(mkdir $sourceInstallDir)`n"
	}
	$uri = "https://archive.apache.org/dist/tomcat/tomcat-8/v${tomcat_version}/bin/apache-tomcat-${tomcat_version}.exe"
	executeExpression "(New-Object System.Net.WebClient).DownloadFile(`"$uri`", `"$sourceInstallDir\$apacheTomcatInstallFileName`")" 
	$hashValue = executeExpression "Get-FileHash `"$sourceInstallDir\$apacheTomcatInstallFileName`" -Algorithm MD5"
	if ($hashValue = $md5) {
		Write-Host "[$scriptName] MD5 ($md5) check successful"
	} else {
		Write-Host "[$scriptName] MD5 ($md5) check failed! Halting with `$lastexitcode 65"; exit 65
	}
}

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
