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

$scriptName = 'installMuleESB.ps1'

Write-Host
Write-Host "[$scriptName] ---------- start ----------"
Write-Host

$mule_ee_version = $args[0]
if ( $mule_ee_version ) {
	Write-Host "[$scriptName] mule_ee_version       : $mule_ee_version"
} else {
	$mule_ee_version = '3.8.1'
	Write-Host "[$scriptName] mule_ee_version       : $mule_ee_version (default)"
}

$InstallLicense = $args[1]
if ( $InstallLicense ) {
	Write-Host "[$scriptName] InstallLicense        : $InstallLicense"
} else {
	$InstallLicense = 'no'
	Write-Host "[$scriptName] InstallLicense        : $InstallLicense (default)"
}

$destinationInstallDir = $args[2]
if ( $destinationInstallDir ) {
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir"
} else {
	$destinationInstallDir = 'c:\opt'
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir (default)"
}

$sourceInstallDir = $args[3]
if ( $sourceInstallDir) {
	Write-Host "[$scriptName] sourceInstallDir      : $sourceInstallDir"
} else {
	$sourceInstallDir = 'c:\vagrant\.provision'
	Write-Host "[$scriptName] sourceInstallDir      : $sourceInstallDir (default)"
}

$muleDistribution = 'mule-enterprise-standalone' # this is mule-ee-distribution-standalone in gzip format
$muleServiceName = 'mule_ee'                     # This is just mule in community edition 
$muleInstallDir = "$destinationInstallDir\" + $muleDistribution + '-' + $mule_ee_version
$muleESBEnterpriseInstall = $muleDistribution + '-' + $mule_ee_version
$muleESBEnterpriseInstallFileName = $muleESBEnterpriseInstall + '.zip'

Write-Host "[$scriptName] muleInstallDir        : $muleInstallDir"

Write-Host
Write-Host "[$scriptName] Extract Mule ESB"

try {
	New-Item -path $muleInstallDir -type directory -force | Out-Null
} catch {
	Write-Host "[$scriptName] Failed to create $muleInstallDir"
	throw $_
}	
Write-Host "[$scriptName] Folder installation: $muleInstallDir"

if ( Test-Path "$muleInstallDir" ) {
	Write-Host
	Write-Host "[$scriptName] Remove Existing Install"
	executeExpression "Remove-Item `"$muleInstallDir`" -Recurse"
}

Write-Host
Write-Host "[$scriptName] Unzip file contents to source install directory"
Add-Type -AssemblyName System.IO.Compression.FileSystem
executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory(`'$sourceInstallDir\$muleESBEnterpriseInstallFileName`', `'$destinationInstallDir`')"

Write-Host
Write-Host "[$scriptName] Configure mule environment variable and add to the path"
executeExpression "[System.Environment]::SetEnvironmentVariable(`'MULE_HOME`', `'$muleInstallDir`', `'Machine`')"

$pathEnvVar=[System.Environment]::GetEnvironmentVariable("PATH","Machine")
executeExpression "[System.Environment]::SetEnvironmentVariable(`'PATH`', `'${pathEnvVar};$muleInstallDir\bin`', `'Machine`')"

Write-Host
Write-Host "[$scriptName] Configure the env var for the location of the properties files for all Mule applications"
executeExpression "[System.Environment]::SetEnvironmentVariable(`'CONFIG_FOLDER`', `'$muleInstallDir\conf`', `'Machine`')"

Write-Host
Write-Host "[$scriptName] Perform Configuration ..."
Write-Host "[$scriptName]   Send configuration files to $muleInstallDir"
$workingDirectory = $(pwd)

executeExpression "Copy-Item `'$sourceInstallDir\configs\wrapper.conf`' `'$muleInstallDir\conf\wrapper.conf`'"
executeExpression "Copy-Item `'$sourceInstallDir\configs\mule-agent.yml`' `'$muleInstallDir\conf\mule-agent.yml`'"
executeExpression "Copy-Item `'$sourceInstallDir\configs\Set-Affinity-MuleEE-Task-Definition.xml`' `'$muleInstallDir\conf\Set-Affinity-MuleEE-Task-Definition.xml`'"
executeExpression "Copy-Item `'$sourceInstallDir\configs\Set-Affinity-MuleEE-Task.ps1`' `'$muleInstallDir\conf\Set-Affinity-MuleEE-Task.ps1`'"

if ($InstallLicense -eq "yes") {
	# Copy the license (this is the digested license). With the digested license, we can skip to run the install license script
	# the script doen not work properly from a remote power shell connection anyway
	executeExpression "Copy-Item `'$sourceInstallDir\configs\muleLicenseKey.lic`' `'$muleInstallDir\conf\muleLicenseKey.lic`'"

	# Copy the task definition and script that check if the license has been succesfully installed and if it is valid
	executeExpression "Copy-Item `'$sourceInstallDir\configs\Verify-License-MuleEE-Task-Definition.xml`' `'$muleInstallDir\conf\Verify-License-MuleEE-Task-Definition.xml`'" 
	executeExpression "Copy-Item `'$sourceInstallDir\configs\Verify-License-MuleEE-Task.ps1`' `'$muleInstallDir\conf\Verify-License-MuleEE-Task.ps1`'"
}

Write-Host
$value='replacewithkey'
$file ="$muleInstallDir\conf\wrapper.conf"
Write-Host "[$scriptName] Replace @MULE_KEY@ with `$value in $file"
(Get-Content $file | ForEach-Object { $_ -replace "@MULE_KEY@", "$value" } ) | Set-Content $file

Write-Host
Write-Host "[$scriptName] Mule EE Standalone installation ..."
Write-Host "[$scriptName] Setting affinity to single process ..."
Write-Host
try {
	$winDir=$(Get-ChildItem -Path Env:\WinDir).Value;
	Copy-Item "$muleInstallDir\conf\Set-Affinity-MuleEE-Task.ps1" $winDir -Recurse -Force | Out-Null
	$taskDefFile="$muleInstallDir\conf\Set-Affinity-MuleEE-Task-Definition.xml"
	(Get-Content $taskDefFile | ForEach-Object { $_ -replace "@MULE_TASK_SCRIPT_HOME@", $winDir } ) | Set-Content $taskDefFile	
	
	#create the scheduller task that sets the Mule affinity to 1 CPU
	New-EventLog -LogName System -Source 'Mule Enterprise Edition' | Out-Null	
	Start-Process schtasks -ArgumentList "/create /TN Set-Affinity-MuleEE-Task /XML `"$taskDefFile`"" -NoNewWindow -Wait
} catch {
	Write-Host "Setting Mule affinity failed!" -ForegroundColor Red
	throw $_
}	
Write-Host "[$scriptName] Setting affinity complete."
Write-Host

Write-Host
Write-Host "[$scriptName] Start and verify >"
Write-Host
Write-Host "[$scriptName] InstallMule EE as a windows service >>"
try {
	Start-Process "$muleInstallDir\bin\mule" -ArgumentList "install" -Wait
} catch {
	Write-Host "Unexpected Error. Error details: $_.Exception.Message" -ForegroundColor Red
	throw $_
}	
Write-Host "[$scriptName] Start Mule windows service"
Write-Host
try {
	$service = Start-Service "$muleServiceName" -WarningAction SilentlyContinue -PassThru
	if ($service.status -ine 'Running') {
		Throw "Could not start service mule"
	}		
} catch {
	Write-Host "[$scriptName] Mule service startup exception : $_.Exception.Message" -ForegroundColor Red
	throw $_
}	

# Install the task scheduller that verifies the EE license 
Write-Host "[$scriptName] Install license ($InstallLicense)"
if ($InstallLicense -eq "yes") {
	Write-Host
	Write-Host "[$scriptName] Install Mule License Verifier scheduller ..."
	Write-Host
	try {
		$winDir = $(Get-ChildItem -Path Env:\WinDir).Value
		Copy-Item "$muleInstallDir\conf\Verify-License-MuleEE-Task.ps1" $winDir -Recurse -Force | Out-Null
		$taskDefFile = "$muleInstallDir\conf\Verify-License-MuleEE-Task-Definition.xml"
		(Get-Content $taskDefFile | ForEach-Object { $_ -replace "@MULE_TASK_SCRIPT_HOME@", $winDir } ) | Set-Content $taskDefFile	
		
		#create the scheduller task that right after creation will check the license status
		#the check of the license uses the provided Mule's batch command: "mule.bat -verifyLicense"
		if (-not [System.Diagnostics.EventLog]::SourceExists("Mule Enterprise Edition")) {
			New-EventLog -LogName System -Source 'Mule Enterprise Edition' | Out-Null	
		}
		Start-Process schtasks -ArgumentList "/create /TN Verify-License-MuleEE-Task /XML `"$taskDefFile`"" -NoNewWindow -Wait
	} catch {
		Write-Host "[$scriptName] Installing Mule License Verifier scheduller failed !" -ForegroundColor Red
		throw $_
	}	
	Write-Host "[$scriptName] Install Mule License Verifier scheduller complete."
	Write-Host			
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host
