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
Write-Host "[$scriptName] ---------- start ----------"
Write-Host

$tomcat_version = $args[0]
if ( $args[0] ) {
	Write-Host "[$scriptName] tomcat_version        : $tomcat_version"
} else {
	Write-Host "[$scriptName] tomcat_version not passed!"; exit 105
}

$sourceInstallDir      = 'c:\vagrant\provisioning'
$destinationInstallDir = 'C:\app'
$tomcatServiceName     = "Tomcat8"
$tomcatHomeDir         = "$destinationInstallDir\apache-tomcat-$tomcat_version"

# Create the installation directory for Tomcat
try {
	New-Item -path $tomcatHomeDir -type directory -force | Out-Null
} catch {
	Write-Host "Unexpected Error. Error details: $_.Exception.Message"
	throw $_
}		
Write-Host "    Folder installation: $tomcatHomeDir"

# Install Tomcat as a Windows Service
$apacheTomcatInstallFileName="apache-tomcat-" + $tomcat_version + ".exe";
Write-Host "    Installing Tomcat as Windows Service ..."
try {
	Start-Process "$sourceInstallDir\$apacheTomcatInstallFileName" -ArgumentList "/S /D=$tomcatHomeDir" -Wait
	Start-Process "$tomcatHomeDir\bin\Tomcat8.exe" -ArgumentList "//US//$tomcatServiceName --Startup=Auto" -Wait
} catch {
	Write-Host "Unexpected Error. Error details: $_.Exception.Message"
	throw $_
}		
Write-Host
Write-Host "    [System.Environment]::SetEnvironmentVariable(`"CATALINA_HOME`", `"$tomcatHomeDir`", `"Machine`")"
[System.Environment]::SetEnvironmentVariable("CATALINA_HOME", "$tomcatHomeDir", "Machine")

$pathEnvVar=[System.Environment]::GetEnvironmentVariable("PATH","Machine")
Write-Host "    [System.Environment]::SetEnvironmentVariable(`"PATH`", $pathEnvVar + `";$tomcatHomeDir\bin`", `"Machine`")"
[System.Environment]::SetEnvironmentVariable("PATH", $pathEnvVar + ";$tomcatHomeDir\bin", "Machine")

try {
 	$service = Start-Service "$tomcatServiceName" -WarningAction SilentlyContinue -PassThru
 	if ($service.status -ine 'Running') {
 		Throw "Could not start service $tomcatServiceName"
 	} else {
		Write-Host
		Write-Host "    [RemotePowershell] $tomcatServiceName Service is $service.status"
 	}			
} catch {
 	Write-Error -Message "Unexpected Error. Error details: $_.Exception.Message"
 	Exit 1
}		

# Apply the available mocks
$array = @(
	"mockAccessControlSoap.war",
	"mockAdministrationServiceSoap.war",
	"mockTopicRegisterService-1.1SOAP11Binding.war",
	"mockVehicleRecallSoap.war",
	"mockVehicleSoap.war"
)
foreach ($element in $array) {
	Copy-Item "C:\vagrant\provisioning\$element" "$tomcatHomeDir\webapps"
}

Write-Host "Open port for external access"
netsh advfirewall firewall add rule name="Open Tomcat Port 8080" dir=in action=allow protocol=TCP localport=8080

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host
