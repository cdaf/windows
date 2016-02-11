# Generic file copy wrapper
$sourceFile = $args[0]
$deployHost = $args[1]
$deployLand = $args[2]
$remoteUser = $args[3]
$remoteCred = $args[4]

$scriptName = $myInvocation.MyCommand.Name

$userName = [Environment]::UserName
$WORK_DIR = $(pwd)
 
write-host "[$scriptName]   sourceFile = $sourceFile"
write-host "[$scriptName]   deployHost = $deployHost"
write-host "[$scriptName]   deployLand = $deployLand"
write-host "[$scriptName]   remoteUser = $remoteUser"
write-host "[$scriptName]   remoteCred = *************"
write-host "[$scriptName]   WORK_DIR   = $WORK_DIR"

# If remote user specifified, build the credentials object from name and password file
if ($remoteUser) {

	$securePassword = ConvertTo-SecureString $remoteCred -asplaintext -force
	$cred = New-Object System.Management.Automation.PSCredential ($remoteUser, $securePassword)

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

# Copy Package
try {
	& $WORK_DIR\copy.ps1 $sourceFile $deployLand $WORK_DIR
	if(!$?){ taskError "COPY_FILE_ERROR" }
} catch { taskException "COPY_FILE_EXCEPTION"  $_ }
