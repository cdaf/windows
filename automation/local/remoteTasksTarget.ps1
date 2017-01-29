function taskException ($trapID, $exception) {
    write-host "[$scriptName] Caught an exception for Trap ID $trapID :" -ForegroundColor Red
	echo $_.Exception|format-list -force
	throw $trapID
}

$ENVIRONMENT = $args[0]
$SOLUTION = $args[1]
$BUILD = $args[2]
$DEPLOY_TARGET = $args[3]
$WORK_DIR_DEFAULT = $args[4]

$scriptName = $myInvocation.MyCommand.Name

$propertiesFile = "$WORK_DIR_DEFAULT\propertiesForRemoteTasks\$DEPLOY_TARGET"

write-host "[$scriptName] propertiesFile : $propertiesFile"

$deployHost = getProp "deployHost"
$deployLand = getProp "deployLand"
$remoteUser = getProp "remoteUser"
$remoteCred = getProp "remoteCred"
$decryptThb = getProp "decryptThb"
$warnondeployerror = getProp "warnondeployerror"

$userName = [Environment]::UserName

write-host "[$scriptName]   deployHost = $deployHost"
write-host "[$scriptName]   deployLand = $deployLand"
write-host "[$scriptName]   remoteUser = $remoteUser"
write-host "[$scriptName]   remoteCred = $remoteCred"
write-host "[$scriptName]   decryptThb = $decryptThb"

# Create a reusable Remote PowerShell session handler
# If remote user specifified, build the credentials object from name and encrypted password file
if ($remoteUser) {
	try {
		if ($decryptThb) {
			$userpass = & .\${WORK_DIR_DEFAULT}\decryptKey.ps1 .\${WORK_DIR_DEFAULT}\cryptLocal\$remoteCred $decryptThb
		    $password = ConvertTo-SecureString $userpass -asplaintext -force
		} else {
			$password = get-content $remoteCred | convertto-securestring
		}
		$cred = New-Object System.Management.Automation.PSCredential ($remoteUser, $password )
	} catch {
		taskException "REMOTE_TASK_DECRYPT" $_
	}
}

# Initialise the session handle
$session = $null

# Extract package artefacts and move to runtime location
if ($remoteUser) {

	if ( $deployHost.contains(":") ) {

		write-host 
		write-host "[$scriptName] Connect using $remoteUser and URI $deployHost"
		write-host 
		try {
			$session = New-PSSession -credential $cred -connectionUri $deployHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "REMOTE_URI_SESSION_ERROR" }
		} catch { taskException "REMOTE_URI_SESSION_EXCEPTION" $_ }

	} else {

		write-host 
		write-host "[$scriptName] Connect using $remoteUser"
		write-host 
		try {
			$session = New-PSSession -credential $cred -ComputerName $deployHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "REMOTE_USER_SESSION_ERROR" }
		} catch { taskException "REMOTE_USER_SESSION_EXCEPTION" $_ }

	}

} else {

	if ( $deployHost.contains(":") ) {

		write-host 
		write-host "[$scriptName] Connect using NTLM ($userName) URI $deployHost"
		write-host 
		try {
			$session = New-PSSession -connectionUri $deployHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "NTLM_URI_SESSION_ERROR" }
		} catch { taskException "NTLM_URI_SESSION_EXCEPTION" $_ }

	} else {

		write-host 
		write-host "[$scriptName] Connect using NTLM ($userName)"
		write-host 
		try {
			$session = New-PSSession -ComputerName $deployHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "NTLM_USER_SESSION_ERROR" }
		} catch { taskException "NTLM_USER_SESSION_EXCEPTION" $_ }
	}
}

# If the package has already been delivered and processed, rename existing file and folder
try {
	Invoke-Command -session $session -File $WORK_DIR_DEFAULT\remotePackageManagement.ps1 -Args $deployLand,$SOLUTION-$BUILD
	if(!$?){ taskError "PACKAGE_TEST_ERROR" }
} catch { taskException "PACKAGE_TEST_EXCEPTION"  $_ }

# Copy Package
try {
	& $WORK_DIR_DEFAULT\copy.ps1 $SOLUTION-$BUILD.zip $deployLand $WORK_DIR_DEFAULT
	if(!$?){ taskError "COPY_PACKAGE_ERROR" }
} catch { taskException "COPY_PACKAGE_EXCEPTION"  $_ }

# Extract package artefacts and move to runtime location
write-host 
write-host "[$scriptName] Extract package artefacts to $deployLand\$SOLUTION-$BUILD"
try {
	Invoke-Command -session $session -File $WORK_DIR_DEFAULT\extract.ps1 -Args $deployLand,$SOLUTION-$BUILD
	if(!$?){ taskError "EXTRACT_ERROR" }
} catch { taskException "EXTRACT_EXCEPTION"  $_ }

# Copy Target Properties file into the extracted directory on the remote host
try {
	& $WORK_DIR_DEFAULT\copy.ps1 $propertiesFile $deployLand\$SOLUTION-$BUILD $WORK_DIR_DEFAULT 
	if(!$?){ taskError "COPY_PROPERTIES_ERROR" }
} catch { taskException "COPY_PROPERTIES_EXCEPTION"  $_ }

# Trigger the Loosely coupled remote execution (principle is that this can be trigger manually for disconnected hosts)
# Automated trigger passes workspace, this is not required for manual deploy as it is expected that the user has navigated to the workspace

write-host 
write-host "[$scriptName] Transfer control to the remote host" -ForegroundColor Blue
write-host 
try {
	Invoke-Command -session $session -File $WORK_DIR_DEFAULT\deploy.ps1 -Args $DEPLOY_TARGET,$deployLand\$SOLUTION-$BUILD,$warnondeployerror
} catch { taskException "REMOTEUSER_POWERSHELL_EXCEPTION" $_ }
