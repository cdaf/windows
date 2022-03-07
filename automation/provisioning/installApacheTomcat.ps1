Param (
	[string]$tomcat_version,
	[string]$sourceInstallDir,
	[string]$destinationInstallDir,
	[string]$SHA512
)

cmd /c "exit 0"
$scriptName = 'installApacheTomcat.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------"

if ( $tomcat_version ) {
	Write-Host "[$scriptName] tomcat_version        : $tomcat_version"
} else {
	$tomcat_version = '8.5.40'
	$SHA512 = 'dce55d3073dae3a91f3b25a0f6a0c78a9c01bafda3e40fee30ef760e3e73a1256f75502148f25d7eab59e753756279005ff3bb6ea3013796b0629dab05a09cf0'
	Write-Host "[$scriptName] tomcat_version        : $tomcat_version (default)"
}

if ( $sourceInstallDir ) {
	Write-Host "[$scriptName] sourceInstallDir      : $sourceInstallDir"
} else {
	$sourceInstallDir = "$env:TEMP"
	Write-Host "[$scriptName] sourceInstallDir      : $sourceInstallDir (default)"
}

if ( $destinationInstallDir ) {
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir"
} else {
	$destinationInstallDir = 'C:\apache'
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir (default)"
}

if ( $SHA512 ) {
	Write-Host "[$scriptName] SHA512                : $SHA512"
} else {
	Write-Host "[$scriptName] SHA512                : (not supplied, hash check will not be attempted)"
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
		Write-Host "[$scriptName] Created $(mkdir $tomcatHomeDir)"
	} catch {
		Write-Host "CREATE_DESTINATION_DIRECTORY_EXCEPTION"
		echo $_.Exception | format-list -force; exit 1461
	}
}		
Write-Host
# Install Tomcat as a Windows Service
$apacheTomcatInstallFileName = "apache-tomcat-" + $tomcat_version + ".exe";

if ( Test-Path "$sourceInstallDir\$apacheTomcatInstallFileName" ) {
	Write-Host "[$scriptName] Media ($sourceInstallDir\$apacheTomcatInstallFileName) exists, download not required."
} else {
	# Create media cache if missing
	if (!( Test-Path $sourceInstallDir )) {
		Write-Host "[$scriptName] Created $(mkdir $sourceInstallDir)`n"
	}
	$uri = "https://archive.apache.org/dist/tomcat/tomcat-8/v${tomcat_version}/bin/apache-tomcat-${tomcat_version}.exe"
	executeExpression "(New-Object System.Net.WebClient).DownloadFile(`"$uri`", `"$sourceInstallDir\$apacheTomcatInstallFileName`")" 
}
if ( $SHA512 ) {
	$return = executeExpression "Get-FileHash `"$sourceInstallDir\$apacheTomcatInstallFileName`" -Algorithm SHA512"
	$hash = $($return.Hash)
	if ( $hash -eq $SHA512 ) {
		Write-Host "[$scriptName] SHA512 ($SHA512) check successful"
	} else {
		Write-Host "[$scriptName] SHA512 check failed!"
		Write-Host "[$scriptName]   Expecting : $SHA512"
		Write-Host "[$scriptName]   Received  : $hash"
		Write-Host "[$scriptName]   Exiting with `$lastexitcode 1465" -foregroundcolor "Red" ; exit 1465
	}
}

if ( Test-Path $sourceInstallDir\$apacheTomcatInstallFileName ) {
	Write-Host "[$scriptName] Installing Tomcat as Windows Service ..."
	try {
		Write-Host "`n[$scriptName] `$proc = Start-Process -FilePath `"$sourceInstallDir\$apacheTomcatInstallFileName`" -ArgumentList `"/S /D=$tomcatHomeDir`" -PassThru -Wait -NoNewWindow -RedirectStandardOutput stdout.log -RedirectStandardError stderr.log"
		$proc = Start-Process -FilePath "$sourceInstallDir\$apacheTomcatInstallFileName" -ArgumentList "/S /D=$tomcatHomeDir" -PassThru -Wait -NoNewWindow -RedirectStandardOutput stdout.log -RedirectStandardError stderr.log
		Get-Content stdout.log
		if ( $proc.ExitCode -ne 0 ) {
			Get-Content stderr.log
			Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
		    exit $proc.ExitCode
		}
		Write-Host "`n[$scriptName] `$proc = Start-Process -FilePath `"$tomcatHomeDir\bin\Tomcat8.exe`" -ArgumentList `"//US//$tomcatServiceName --Startup=Auto`" -PassThru -Wait -NoNewWindow -RedirectStandardOutput stdout.log -RedirectStandardError stderr.log"
		$proc = Start-Process -FilePath "$tomcatHomeDir\bin\Tomcat8.exe" -ArgumentList "//US//$tomcatServiceName --Startup=Auto" -PassThru -Wait -NoNewWindow -RedirectStandardOutput stdout.log -RedirectStandardError stderr.log
		Get-Content stdout.log
		if ( $proc.ExitCode -ne 0 ) {
			Get-Content stderr.log
			Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
		    exit $proc.ExitCode
		}
	} catch {
		Write-Host "INSTALL_EXCEPTION"
		echo $_.Exception | format-list -force; exit 1462
	}
} else {
	Write-Host "[$scriptName] Install file ($sourceInstallDir\$apacheTomcatInstallFileName) not found!" -foregroundcolor "Red"
	exit 1463
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
 		Write-Host "[$scriptName] Could not start service $tomcatServiceName" -foregroundcolor Red; exit 1464
 	} else {
		Write-Host "[$scriptName] $tomcatServiceName Service status = $service.status"
 	}			
} catch {
	Write-Host "START_EXCEPTION"
	echo $_.Exception | format-list -force; exit 1465
}		

Write-Host "`n[$scriptName] ---------- stop -----------`n"
