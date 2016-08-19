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

$sourceInstallDir = $args[0]
if ( $sourceInstallDir) {
	Write-Host "[$scriptName] sourceInstallDir      : $sourceInstallDir"
} else {
	Write-Host "[$scriptName] sourceInstallDir not passed, exit with error code 103."; exit 103
}

$destinationInstallDir = $args[1]
if ( $destinationInstallDir ) {
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir"
} else {
	Write-Host "[$scriptName] destinationInstallDir not passed, exit with error code 104."; exit 104
}

$mule_ee_version = $args[2]
if ( $mule_ee_version ) {
	Write-Host "[$scriptName] mule_ee_version       : $mule_ee_version"
} else {
	Write-Host "[$scriptName] mule_ee_version not passed, exit with error code 105."; exit 105
}

$InstallLicense = $args[3]
if ( $InstallLicense ) {
	Write-Host "[$scriptName] InstallLicense        : $InstallLicense"
} else {
	Write-Host "[$scriptName] InstallLicense not passed, exit with error code 106."; exit 106
}

$muleInstallDir = "$destinationInstallDir\mule-enterprise-" + $mule_ee_version
Write-Host "[$scriptName] muleInstallDir        : $muleInstallDir"

Write-Host
Write-Host "  Extract Mule ESB"

try {
	New-Item -path $muleInstallDir -type directory -force | Out-Null
} catch {
	Write-Host "Failed to create $muleInstallDir"
	throw $_
}	
Write-Host "    Folder installation: $muleInstallDir"

$muleESBEnterpriseInstallFileName = "mule-ee-distribution-standalone-" + $mule_ee_version + ".zip";

# Unzip file contents to source install directory
Add-Type -AssemblyName System.IO.Compression.FileSystem
executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $muleInstallDir)"

Write-Host "  Configuring environment variables ..."
executeExpression "[System.Environment]::SetEnvironmentVariable(`'MULE_HOME`', `'$muleInstallDir`', `'Machine`')"

$pathEnvVar=[System.Environment]::GetEnvironmentVariable("PATH","Machine")
executeExpression "[System.Environment]::SetEnvironmentVariable(`'PATH`', `'${pathEnvVar};$muleInstallDir\bin`', `'Machine`')"

# Configure the env var for the location of the properties files for all Mule applications
executeExpression "[System.Environment]::SetEnvironmentVariable(`'CONFIG_FOLDER`', `'$muleInstallDir\conf`', `'Machine`')"

# Copy the agent plugin, this will be automatically extracted and installed when mule starts
Write-Host "  Copy agent plugin (mule-agent-plugin.zip) to $muleInstallDir\plugins\ ..."
executeExpression "Copy-Item $sourceInstallDir\mule-agent-plugin.zip $muleInstallDir\plugins\ -recurse -force"

Write-Host
Write-Host "  [$scriptName] Perform Configuration ..."
Write-Host
Write-Host "    [$scriptName] Send configuration files to $muleInstallDir"
$workingDirectory = $(pwd)

& .\remoteCopy.ps1 $workingDirectory\configs\mule\wrapper.conf $WINRM_HOSTNAME "$muleInstallDir\conf" $username $userpass 
& .\remoteCopy.ps1 $workingDirectory\configs\mule\mule-agent.yml $WINRM_HOSTNAME "$muleInstallDir\conf" $username $userpass 
& .\remoteCopy.ps1 $workingDirectory\configs\mule\Set-Affinity-MuleEE-Task-Definition.xml $WINRM_HOSTNAME "$muleInstallDir\conf" $username $userpass 
& .\remoteCopy.ps1 $workingDirectory\configs\mule\Set-Affinity-MuleEE-Task.ps1 $WINRM_HOSTNAME "$muleInstallDir\conf" $username $userpass 

if ($InstallLicense -eq "yes") {
	# Copy the license (this is the digested license). With the digested license, we can skip to run the install license script
	# the script doen not work properly from a remote power shell connection anyway
	& .\remoteCopy.ps1 $workingDirectory\configs\mule\muleLicenseKey.lic $WINRM_HOSTNAME "$muleInstallDir\conf" $username $userpass 

	# Copy the task definition and script that check if the license has been succesfully installed and if it is valid
	& .\remoteCopy.ps1 $workingDirectory\configs\mule\Verify-License-MuleEE-Task-Definition.xml $WINRM_HOSTNAME "$muleInstallDir\conf" $username $userpass 
	& .\remoteCopy.ps1 $workingDirectory\configs\mule\Verify-License-MuleEE-Task.ps1 $WINRM_HOSTNAME "$muleInstallDir\conf" $username $userpass 
}

Write-Host "    [$scriptName] Detokenise Configuration"
Write-Host
$plainTextPass = ./decryptKey.ps1 $passwordFile $certificateThumb
$argList = @("$muleInstallDir\conf\wrapper.conf", "@MULE_KEY@", "$plainTextPass")
try {
	Invoke-Command -ComputerName $vmHost -credential $cred -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck) -ArgumentList $argList {
		if ( $args[0] ) {
			$file = $args[0]
			Write-Host "      [RemotePowershell] file  : $file"
		} else {
			throw "[RemotePowershell] file not passed"
		}
		
		if ( $args[1] ) {
			$token = $args[1]
			Write-Host "      [RemotePowershell] token : $token"
		} else {
			throw "[RemotePowershell] token not passed"
		}

		if ( $args[2] ) {
			$value = $args[2]
			Write-Host "      [RemotePowershell] value : ************* "
		} else {
			throw "[RemotePowershell] value not passed"
		}
		Write-Host
		Write-Host "      Replace $token with `$value in $file"
		(Get-Content $file | ForEach-Object { $_ -replace "$token", "$value" } ) | Set-Content $file
		Write-Host		
	}

    if(!$?) { Write-Host "[$scriptName] Detokenisation Failure!! exit 213"; exit 213 }
} catch { Write-Host "[$scriptName] Detokenisation Exception thrown, $_ exit 214"; exit 214 }

$argList = @( "$sourceInstallDir", "$destinationInstallDir", "$muleInstallDir", "$InstallLicense")

try {
	Invoke-Command -ComputerName $vmHost -credential $cred -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck) -ArgumentList $argList {
		if ( $args[0] ) {
			$sourceInstallDir = $args[0]
			Write-Host "  [RemotePowershell] sourceInstallDir      : $sourceInstallDir"
		} else {
			Write-Host "  [RemotePowershell] sourceInstallDir not passed, exit with error code 220."; exit 220
			throw "[RemotePowershell] value not passed"
		}

		if ( $args[1] ) {
			$destinationInstallDir = $args[1]
			Write-Host "  [RemotePowershell] destinationInstallDir : $destinationInstallDir"
		} else {
			throw "[RemotePowershell] destinationInstallDir not passed"
		}

		if ( $args[2] ) {
			$muleInstallDir = $args[2]
			Write-Host "  [RemotePowershell] muleInstallDir        : $muleInstallDir"
		} else {
			throw "[RemotePowershell] muleInstallDir not passed"
		}

		if ( $args[3] ) {
			$InstallLicense = $args[3]
			Write-Host "  [RemotePowershell] InstallLicense        : $InstallLicense"
		} else {
			throw "[RemotePowershell] InstallLicense not passed"
		}

		Write-Host
		Write-Host "  Mule EE Standalone installation ..."
		Write-Host
		Write-Host "    [RemotePowershell] Setting affinity to single process ..."
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
		Write-Host "    [RemotePowershell] Setting affinity complete."
		Write-Host

		Write-Host
		Write-Host "  Start and verify >"
		Write-Host
		Write-Host "    [RemotePowershell] InstallMule EE as a windows service >>"
		try {
			Start-Process "$muleInstallDir\bin\mule" -ArgumentList "install" -Wait
		} catch {
			Write-Host "Unexpected Error. Error details: $_.Exception.Message" -ForegroundColor Red
			throw $_
		}	
		Write-Host "    << [RemotePowershell] InstallMule EE as a windows service"
		Write-Host
		try {
			$service = Start-Service "mule_ee" -WarningAction SilentlyContinue -PassThru
			if ($service.status -ine 'Running') {
				Throw "Could not start service mule_ee"
			}		
		} catch {
			Write-Host "Mule service startup exception : $_.Exception.Message" -ForegroundColor Red
			throw $_
		}	

		# Install the task scheduller that verifies the EE license 
		Write-Host "  [RemotePowershell] Install license ($InstallLicense)"
		if ($InstallLicense -eq "yes") {
			Write-Host
			Write-Host "    [RemotePowershell] Install Mule License Verifier scheduller ..."
			Write-Host
			try {
			
				$winDir=$(Get-ChildItem -Path Env:\WinDir).Value;
				Copy-Item "$muleInstallDir\conf\Verify-License-MuleEE-Task.ps1" $winDir -Recurse -Force | Out-Null
				$taskDefFile="$muleInstallDir\conf\Verify-License-MuleEE-Task-Definition.xml"
				(Get-Content $taskDefFile | ForEach-Object { $_ -replace "@MULE_TASK_SCRIPT_HOME@", $winDir } ) | Set-Content $taskDefFile	
				
				#create the scheduller task that right after creation will check the license status
				#the check of the license uses the provided Mule's batch command: "mule.bat -verifyLicense"
				if (-not [System.Diagnostics.EventLog]::SourceExists("Mule Enterprise Edition")) {
					New-EventLog -LogName System -Source 'Mule Enterprise Edition' | Out-Null	
				}
				Start-Process schtasks -ArgumentList "/create /TN Verify-License-MuleEE-Task /XML `"$taskDefFile`"" -NoNewWindow -Wait
			} catch {
				Write-Host "Installing Mule License Verifier scheduller failed !" -ForegroundColor Red
				throw $_
			}	
			Write-Host "    [RemotePowershell] Install Mule License Verifier scheduller complete."
			Write-Host			
		}

		Write-Host
		Write-Host -NoNewline "  Verify Agent has installed : "
		$wait = 10
		$retryMax = 10
		$retryCount = 0
		$uri='http://localhost:9999/mule/domains'
		while ( $retryCount -lt $retryMax ) {
		
			try {
			
		        ## Write-Host "[DEBUG] `$response = Invoke-WebRequest -Uri `"$uri`" -UseBasicParsing" -ForegroundColor Blue
				$response = Invoke-WebRequest -Uri "$uri" -UseBasicParsing
				
	        } catch {
	         
				Write-Host "Agent test failed, retry $retryCount of $retryMax, intermediate step pause for $wait seconds..."
				Write-Host
		        ## Write-Host "[DEBUG] sleep $wait" -ForegroundColor Blue
				sleep $wait
		    	Write-Host "[$scriptName] Start-Process amc_setup.bat -ArgumentList `"-U `" -WorkingDirectory `"$muleInstallDir\bin`"  -Wait"
			    Start-Process amc_setup.bat -ArgumentList "-U" -WorkingDirectory "$muleInstallDir\bin"  -Wait
			    if(!$?) {
			    	Write-Host "[$scriptName] amc_setup.bat error has occurred during agent setup"
			    	throw "[$scriptName] amc_setup.bat error has occurred during agent setup"
				}
		        ## Write-Host "[DEBUG] sleep $wait" -ForegroundColor Blue
				
				try {
					Write-Host
			        Write-Host " `$service = Restart-Service `"mule_ee`" -WarningAction SilentlyContinue -PassThru"
					$service = Restart-Service "mule_ee" -WarningAction SilentlyContinue -PassThru
			        ## Write-Host "[DEBUG] if ($service.status -ine 'Running')" -ForegroundColor Blue
					if ($service.status -ine 'Running') {
						Throw "Could not restart service mule_ee"
					}		
				} catch {
					Write-Host "Mule service restart exception : $_.Exception.Message" -ForegroundColor Red
					throw $_
				}	
		        ## Write-Host "[DEBUG] sleep $wait" -ForegroundColor Blue
				
	        }
	        
	        ## Write-Host "[DEBUG] `$response = $response" -ForegroundColor Blue
	        # if successful, set the retry to maximum to stop the loop
	        if ( $response ) {
	        	$retryCount = $retryMax
        	}
        	
			# Increase the pause between steps each retry cycle
			$wait += 10
        	$retryCount += 1
        }
        
        if ( $response ) {
			Write-Host "  SUCCESS"
		} else {
			Write-Host "  Agent verification failed after ${retryCount} retries of ${retryMax}." -ForegroundColor Red
			Write-Host
			throw 'Agent verification failure'
		}
		Write-Host
		Write-Host '  < Start, apply license and verify'
	}	
    if(!$?) { Write-Host "[$scriptName] Invoke Failure!!"; exit 228 }
} catch { Write-Host "[$scriptName] Invoke Exception thrown, $_"; exit 229 }

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host
