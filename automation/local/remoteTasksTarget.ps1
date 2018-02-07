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
	} catch { exceptionExit "REMOTE_TASK_DECRYPT" $_ 23400 }
}

# Initialise the session handle
$session = $null

# Extract package artefacts and move to runtime location
if ($remoteUser) {

	if ( $deployHost.contains(":") ) {

		write-host "`n[$scriptName] Connect using $remoteUser and URI $deployHost`n"
		try {
			$session = New-PSSession -credential $cred -connectionUri $deployHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "REMOTE_URI_SESSION_ERROR" }
		} catch { exceptionExit "REMOTE_URI_SESSION_EXCEPTION" $_ 23401 }

	} else {

		write-host "`n[$scriptName] Connect using $remoteUser`n"
		try {
			$session = New-PSSession -credential $cred -ComputerName $deployHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "REMOTE_USER_SESSION_ERROR" }
		} catch { exceptionExit "REMOTE_USER_SESSION_EXCEPTION" $_ 23402 }

	}

} else {

	if ( $deployHost.contains(":") ) {

		write-host "`n[$scriptName] Connect using NTLM ($userName) URI $deployHost`n"
		try {
			$session = New-PSSession -connectionUri $deployHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "NTLM_URI_SESSION_ERROR" }
		} catch { exceptionExit "NTLM_URI_SESSION_EXCEPTION" $_ 23403 }

	} else {

		write-host "`n[$scriptName] Connect using NTLM ($userName)`n"
		try {
			$session = New-PSSession -ComputerName $deployHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "NTLM_USER_SESSION_ERROR" }
		} catch { exceptionExit "NTLM_USER_SESSION_EXCEPTION" $_ 23404 }
	}
}

# If the package has already been delivered and processed, rename existing file and folder
try {
	Invoke-Command -session $session -File $WORK_DIR_DEFAULT\remotePackageManagement.ps1 -Args $deployLand,$SOLUTION-$BUILD
	if(!$?){ taskError "PACKAGE_TEST_ERROR" }
} catch { exceptionExit "PACKAGE_TEST_EXCEPTION" $_ 23405 }

# Copy Package
try {
	& $WORK_DIR_DEFAULT\copy.ps1 $SOLUTION-$BUILD.zip $deployLand $WORK_DIR_DEFAULT
	if(!$?){ taskError "COPY_PACKAGE_ERROR" }
} catch { exceptionExit "COPY_PACKAGE_EXCEPTION" $_ 23406 }

# Extract package artefacts and move to runtime location
write-host "`n[$scriptName] Extract package artefacts to $deployLand\$SOLUTION-$BUILD"
try {
	Invoke-Command -session $session -File $WORK_DIR_DEFAULT\extract.ps1 -Args $deployLand,$SOLUTION-$BUILD
	if(!$?){ taskError "EXTRACT_ERROR" }
} catch { exceptionExit "EXTRACT_EXCEPTION" $_ 23407 }

# Copy Target Properties file into the extracted directory on the remote host
try {
	& $WORK_DIR_DEFAULT\copy.ps1 $propertiesFile $deployLand\$SOLUTION-$BUILD $WORK_DIR_DEFAULT 
	if(!$?){ taskError "COPY_PROPERTIES_ERROR" }
} catch { exceptionExit "COPY_PROPERTIES_EXCEPTION" $_ 23408 }

# Trigger the Loosely coupled remote execution (principle is that this can be trigger manually for disconnected hosts)
# Automated trigger passes workspace, this is not required for manual deploy as it is expected that the user has navigated to the workspace

write-host "`n[$scriptName] Transfer control to the remote host`n" -ForegroundColor Blue
try {
	Invoke-Command -session $session -File $WORK_DIR_DEFAULT\deploy.ps1 -Args $DEPLOY_TARGET,$deployLand\$SOLUTION-$BUILD,$warnondeployerror
} catch { 
	$exceptionCode = echo $_.tostring()
	[int]$exceptionCode = [convert]::ToInt32($exceptionCode)
	if ( $exceptionCode -ne 0 ){
	    write-host "[$scriptName] EXCEPTION_PASS_BACK Invoke-Command -session $session -File $WORK_DIR_DEFAULT\deploy.ps1 -Args $DEPLOY_TARGET,$deployLand\$SOLUTION-$BUILD,$warnondeployerror" -ForegroundColor Magenta
		write-host "[$scriptName]   Exit with `$LASTEXITCODE $exceptionCode" -ForegroundColor Red
		exit $exceptionCode
	}
}
