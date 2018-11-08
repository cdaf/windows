Param (
	[string]$java_version,
	[string]$architecture,
	[string]$sourceInstallDir,
	[string]$destinationInstallDir,
	[string]$proxy
)

cmd /c "exit 0"
$scriptName = 'installOracleJava.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "`n[$scriptName] ---------- start ----------"

if ( $java_version ) {
	$java_version,$urlUID = $java_version.split('@')
	Write-Host "[$scriptName] java_version          : ${java_version}@${urlUID} (must be passed as version@urlUID)"
} else {
	$java_version = '8u192'
	$urlUID = '8u192-b12/750e1c8617c5452694857ad95c3ee230'
	Write-Host "[$scriptName] java_version          : ${java_version}@${urlUID} (default)"
}

if ( $architecture ) {
	Write-Host "[$scriptName] architecture          : $architecture (choices x64 or i586)"
} else {
	$architecture = 'x64'
	Write-Host "[$scriptName] architecture          : $architecture (default, choices x64 or i586)"
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
	$destinationInstallDir = 'c:\Oracle'
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir (default)"
}

if ($proxy) {
    Write-Host "[$scriptName] proxy                 : $proxy`n"
    executeExpression "`$env:http_proxy = '$proxy'"
} else {
    Write-Host "[$scriptName] proxy                 : (not supplied)"
}

Write-Host

# The installation directory for JDK, the script will create this
$javaInstallDir = "$destinationInstallDir\Java"
$jdkInstallDir = "$javaInstallDir\jdk$java_version"
$jreInstallDir = "$javaInstallDir\jre$java_version"
$jdkInstallFileName = "jdk-" + $java_version + "-windows-" + $architecture + ".exe"

$installer = "$sourceInstallDir\$jdkInstallFileName"
if (!( Test-Path "$installer" )) {
	Write-Host "[$scriptName] $installer not found, attempt to download ..."
	$versionTest = cmd /c curl.exe --version 2`>`&1
	cmd /c "exit 0"
	if ($versionTest -like '*not recognized*') {
		Write-Host "  curl.exe not installed, exiting with error code 6273"; exit 6273
	} else {
		$array = $versionTest.split(" ")
		Write-Host "  curl.exe                : $($array[1])"
	}
	executeExpression "& curl.exe --silent -L -b 'oraclelicense=a' http://download.oracle.com/otn-pub/java/jdk/${urlUID}/jdk-${java_version}-windows-x64.exe --output $sourceInstallDir\$jdkInstallFileName"
}

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
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", "$jdkInstallDir", "Machine")
$pathEnvVar=[System.Environment]::GetEnvironmentVariable("PATH","Machine")
[System.Environment]::SetEnvironmentVariable("PATH", $pathEnvVar + ";$jdkInstallDir\bin", "Machine")

# Reload the path (without logging off and back on)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:JAVA_HOME = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")

Write-Host "`n[$scriptName] `$env:JAVA_HOME = $env:JAVA_HOME`n"

$versionTest = cmd /c java -version 2`>`&1
if ($versionTest -like '*not recognized*') {
	Write-Host "  Java                    : not installed"
} else {
	$array = $versionTest.split(" ")
	$array = $array[2].split('"')
	Write-Host "  Java                    : $($array[1])"
}

$versionTest = cmd /c javac -version 2`>`&1
if ($versionTest -like '*not recognized*') {
	Write-Host "  Java Compiler           : not installed"
} else {
	$array = $versionTest.split(" ")
	if ($array[2]) {
		Write-Host "  Java Compiler           : $($array[2])"
	} else {
		Write-Host "  Java Compiler           : $($array[1])"
	}
}

Write-Host "`n[$scriptName] ---------- stop -----------`n"
