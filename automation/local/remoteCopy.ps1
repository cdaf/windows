# Generic file copy wrapper
$sourceFile = $args[0]
$targetHost = $args[1]
$targetLand = $args[2]
$remoteUser = $args[3]
$remoteCred = $args[4]

$scriptName = $myInvocation.MyCommand.Name

$userName = [Environment]::UserName
$WORK_DIR = $(pwd)
 
if ( Test-Path "$sourceFile" ) {
#	write-host "[$scriptName]   sourceFile : $sourceFile"
} else {
	write-host "[$scriptName]   sourceFile ($sourceFile) does not exist, attempt to list parent directory"
	dir $(split-path $sourceFile)
	exit 200	
}
# write-host "[$scriptName]   targetHost : $targetHost"
# write-host "[$scriptName]   targetLand : $targetLand"
# write-host "[$scriptName]   remoteUser : $remoteUser"
# write-host "[$scriptName]   remoteCred : *************"
# write-host "[$scriptName]   pwd        : $WORK_DIR"

# If remote user specifified, build the credentials object from name and password file
if ($remoteUser) {

	$securePassword = ConvertTo-SecureString $remoteCred -asplaintext -force
	$cred = New-Object System.Management.Automation.PSCredential ($remoteUser, $securePassword)

}

# Initialise the session handle
$session = $null

# Extract package artefacts and move to runtime location
if ($remoteUser) {

	if ( $targetHost.contains(":") ) {

		write-host 
		write-host "[$scriptName] Connect using $remoteUser and URI $targetHost"
		write-host 
		try {
			$session = New-PSSession -credential $cred -connectionUri $targetHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "REMOTE_URI_SESSION_ERROR" }
		} catch { taskException "REMOTE_URI_SESSION_EXCEPTION" $_ }

	} else {

		write-host 
		write-host "[$scriptName] Connect using $remoteUser"
		write-host 
		try {
			$session = New-PSSession -credential $cred -ComputerName $targetHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "REMOTE_USER_SESSION_ERROR" }
		} catch { taskException "REMOTE_USER_SESSION_EXCEPTION" $_ }

	}

} else {

	if ( $targetHost.contains(":") ) {

		write-host 
		write-host "[$scriptName] Connect using NTLM ($userName) URI $targetHost"
		write-host 
		try {
			$session = New-PSSession -connectionUri $targetHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "NTLM_URI_SESSION_ERROR" }
		} catch { taskException "NTLM_URI_SESSION_EXCEPTION" $_ }

	} else {

		write-host 
		write-host "[$scriptName] Connect using NTLM ($userName)"
		write-host 
		try {
			$session = New-PSSession -ComputerName $targetHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "NTLM_USER_SESSION_ERROR" }
		} catch { taskException "NTLM_USER_SESSION_EXCEPTION" $_ }
	}
}

# If target file exists, rename (if left in place, the copy will append to the existing file)
$argList = @("$targetLand\$(split-path $sourceFile -Leaf)")
try {
	Invoke-Command -session $session -ArgumentList $argList {
		$file = $args[0]
		if ( Test-Path $file ) {
			Write-Host "[remoteCopy.ps1] rename existing file to ${file}.orig"
			mv $file "${file}.orig"
		} 
	}
	if(!$?){ taskError "RENAME_FILE_ERROR" }
} catch { taskException "RENAME_FILE_ERROR"  $_ }

# Copy File
try {
	& $WORK_DIR\copy.ps1 $sourceFile $targetLand $WORK_DIR
	if(!$?){ taskError "COPY_FILE_ERROR" }
} catch { taskException "COPY_FILE_EXCEPTION"  $_ }
