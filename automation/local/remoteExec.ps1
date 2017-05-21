function exceptionExit ($taskName) {
    write-host
    write-host "[$scriptName] $taskName failed!" -ForegroundColor Red
    write-host
    write-host "     Returning errorlevel (-1) to DOS" -ForegroundColor Magenta
    write-host
    $host.SetShouldExit(-1)
    exit
}

$scriptName = 'remoteExec'
write-host
write-host "[$scriptName] --- Start ---"

$remHost = $args[0]
$remUser = $args[1]
$remCred = $args[2]
$remThum = $args[3]
$remoteCommand = $args[4]

$scriptName = $myInvocation.MyCommand.Name

if (-not($remHost)) {exceptionExit remHost_NOT_PASSED }
write-host "[$scriptName]   remHost       : $remHost"
write-host "[$scriptName]   remUser       : $remUser"
write-host "[$scriptName]   remCred       : $remCred"
write-host "[$scriptName]   remThum       : $remThum"
if (-not($remoteCommand)) {exceptionExit remoteCommand_NOT_PASSED }
write-host "[$scriptName]   remoteCommand : $remoteCommand"
if ($args[5]) { $argList = @($args[5]) }
if ($args[6]) { $argList += $args[6] }
if ($args[7]) { $argList += $args[7] }
if ($args[8]) { $argList += $args[8] }
if ($args[9]) { $argList += $args[9] }
write-host "[$scriptName]   argList       : $argList"

# Create a reusable Remote PowerShell session handler
# If remote user specifified, build the credentials object from name and encrypted password file
if ( $remUser -ne 'NOT_SUPPLIED' ) {
	if ( $remThum  -ne 'NOT_SUPPLIED' ) {
		$userpass = & .\decryptKey.ps1 .\cryptLocal\$remCred $remThum
	    $password = ConvertTo-SecureString $userpass -asplaintext -force
	} else {
		$password = get-content $remCred | convertto-securestring
	}
	$cred = New-Object System.Management.Automation.PSCredential ($remUser, $password )
}

# Initialise the session handle
$session = $null
if ( $remUser  -ne 'NOT_SUPPLIED' ) {

	if ( $remHost.contains(":") ) {

		write-host 
		write-host "[$scriptName] Connect using $remUser and URI $remHost"
		write-host 
		try {
			$session = New-PSSession -credential $cred -connectionUri $remHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "REMOTE_URI_SESSION_ERROR" }
		} catch { taskException "REMOTE_URI_SESSION_EXCEPTION" $_ }

	} else {

		write-host 
		write-host "[$scriptName] Connect using $remUser"
		write-host 
		try {
			$session = New-PSSession -credential $cred -ComputerName $remHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "REMOTE_USER_SESSION_ERROR" }
		} catch { taskException "REMOTE_USER_SESSION_EXCEPTION" $_ }

	}

} else {

	$userName = [Environment]::UserName
	
	if ( $remHost.contains(":") ) {

		write-host 
		write-host "[$scriptName] Connect using NTLM ($userName) URI $remHost"
		write-host 
		try {
			$session = New-PSSession -connectionUri $remHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "NTLM_URI_SESSION_ERROR" }
		} catch { taskException "NTLM_URI_SESSION_EXCEPTION" $_ }

	} else {

		write-host 
		write-host "[$scriptName] Connect using NTLM ($userName)"
		write-host 
		try {
			$session = New-PSSession -ComputerName $remHost -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck)
			if(!$?){ taskError "NTLM_USER_SESSION_ERROR" }
		} catch { taskException "NTLM_USER_SESSION_EXCEPTION" $_ }
	}
}

# Now that a session has been establised, use to either execute a command remotely or execute a local powershell script remotely 
if ( [System.IO.Path]::GetExtension($remoteCommand).contains(".ps1") ) {

	write-host "[$scriptName] Execute $remoteCommand as script ..."
	write-host 
	try {
		Invoke-Command -session $session -File .\$remoteCommand -Args $argList
		if(!$?){ taskError "EXECUTE_SCRIPT_ERROR" }
	} catch { taskException "PACKAGE_TEST_EXCEPTION"  $_ }

} else {
 
	write-host "[$scriptName] Execute $remoteCommand as command ..."
	write-host 
	try {
		Invoke-Expression "Invoke-command -Session `$session -ScriptBlock {	$remoteCommand $argList }"
		if(!$?){ taskError "EXECUTE_COMMAND_ERROR" }
	} catch { taskException "EXECUTE_COMMAND_EXCEPTION"  $_ }

}
write-host "[$scriptName] --- Finish ---"
