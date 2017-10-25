# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

$scriptName = 'installOracleJava.ps1'

Write-Host
Write-Host "[$scriptName] ---------- start ----------"

$java_version = $args[0]
if ( $java_version ) {
	Write-Host "[$scriptName] java_version          : $java_version"
} else {
	$java_version = '8u151'
	Write-Host "[$scriptName] java_version          : $java_version (default)"
}

$architecture = $args[1]
if ( $architecture ) {
	Write-Host "[$scriptName] architecture          : $architecture (choices x64 or i586)"
} else {
	$architecture = 'x64'
	Write-Host "[$scriptName] architecture          : $architecture (default, choices x64 or i586)"
}

$sourceInstallDir = $args[2]
if ( $sourceInstallDir ) {
	Write-Host "[$scriptName] sourceInstallDir      : $sourceInstallDir"
} else {
	$sourceInstallDir = 'C:\.provision'
	Write-Host "[$scriptName] sourceInstallDir      : $sourceInstallDir (default)"
}

$destinationInstallDir = $args[3]
if ( $destinationInstallDir ) {
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir"
} else {
	$destinationInstallDir = 'c:\Oracle'
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir (default)"
}

Write-Host

# The installation directory for JDK, the script will create this
$javaInstallDir = "$destinationInstallDir\Java"
$jdkInstallDir = "$javaInstallDir\jdk$java_version"
$jreInstallDir = "$javaInstallDir\jre$java_version"
$jdkInstallFileName = "jdk-" + $java_version + "-windows-" + $architecture + ".exe"

$installer = "$sourceInstallDir\$jdkInstallFileName"
if ( Test-Path "$installer" ) {
	Write-Host "[$scriptName] Installing the JDK ..."
	Write-Host "[$scriptName]   Installer : $installer"
} else {
	Write-Host
	Write-Host "[$scriptName] $installer not found! Not action attempted"; exit 4
}

try {
	New-Item -path $javaInstallDir -type directory -force | Out-Null
} catch {
	Write-Host "Java Install Exception: $_.Exception.Message" -ForegroundColor Red
	throw $_
}

# Arguments which switch the JDK install to a silent process with no reboots, and sets up the log directory
$arguments =@("/s /INSTALLDIRPUBJRE=`"$jreInstallDir`" INSTALL_SILENT=Enable REBOOT=Disable INSTALLDIR=`"$jdkInstallDir`"")
Write-Host "    Arguments : $arguments"
Write-Host
Write-Host "    Installing the JDK ..."

try {
	$proc = Start-Process -FilePath "$installer" -ArgumentList $arguments  -Wait -PassThru

	if($proc.ExitCode -ne 0) {
		Write-Host "[$scriptName] Failure : Start-Process -FilePath `"$installer`" -ArgumentList $arguments  -Wait -PassThru" -ForegroundColor Red
		throw JDK_INSTALL_ERROR 
	}
} catch {
	Write-Host "[$scriptName] Exception : Start-Process -FilePath `"$installer`" -ArgumentList $arguments  -Wait -PassThru" -ForegroundColor Red
	throw $_
}
Write-Host "[$scriptName] Installing the JDK complete."
Write-Host

# Configure environment variables
Write-Host "[$scriptName] Configuring environment variables ..."
Write-Host
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", "$jdkInstallDir", "Machine")
$pathEnvVar=[System.Environment]::GetEnvironmentVariable("PATH","Machine")
[System.Environment]::SetEnvironmentVariable("PATH", $pathEnvVar + ";$jdkInstallDir\bin", "Machine")
Write-Host
Write-Host "[$scriptName] Configuring environment variables complete, reload path."
Write-Host

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "[$scriptName]   `$env:Path = $env:Path"

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host
