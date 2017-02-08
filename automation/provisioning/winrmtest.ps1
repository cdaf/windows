Write-Host
Write-Host "[winrmtest.ps1] ---------- start ----------"
Write-Host

$vmHost = $args[0]
if ( $vmHost ) {
	Write-Host "[winrmtest.ps1] vmHost          : $vmHost"
} else {
	Write-Host "[winrmtest.ps1] VM host not passed, exit with error code 100."; exit 100
}

$username = $args[1]
if ( $username ) {
	Write-Host "[winrmtest.ps1] username        : $username"
} else {
	Write-Host "[winrmtest.ps1] Username not passed, exit with error code 101."; exit 101
}

$userpass = $args[2]
if ( $userpass ) {
	Write-Host "[winrmtest.ps1] userpass        : ***********"
} else {
	Write-Host "[winrmtest.ps1] Password not passed, exit with error code 102."; exit 102
}

$successRequired = $args[3]
if ( $successRequired ) {
	Write-Host "[winrmtest.ps1] successRequired : $successRequired"
} else {
	$successRequired = 2
	Write-Host "[winrmtest.ps1] successRequired : $successRequired (default)"
}

$retries = $args[4]
if ( $retries ) {
	Write-Host "[winrmtest.ps1] retries         : $retries"
} else {
	$retries = 5
	Write-Host "[winrmtest.ps1] retries         : $retries (default)"
}
Write-Host

# Add target host to trusted hosts list
try {
	Set-WSManInstance -ResourceURI winrm/config/client -ValueSet @{TrustedHosts=$vmHost}
} catch {
	Write-Host "[vagrantupIgnoreWinRM.ps1] unable to add host, assuming on domain, proceeding ..."
}

# Create a credential object with the user ID and userpass
$securePassword = ConvertTo-SecureString $userpass -asplaintext -force
$cred = New-Object System.Management.Automation.PSCredential ($username, $securePassword)
$i = 0
$timeout = 60
$successCount = 0
do {
	# Test connection and echo basic target details
	try {
		Invoke-Command -ComputerName $vmHost -credential $cred -SessionOption (New-PSSessionOption -SkipRevocationCheck -SkipCACheck -SkipCNCheck) {
			Write-Host
			Write-Host "  RemotePowershell user     : $(whoami)"	
			Write-Host "  RemotePowershell hostname : $(hostname)"	
			Write-Host
			Write-Host "[vagrantupIgnoreWinRM.ps1] Test successfull"
			Write-Host
		}
	    if($?) { $successCount ++ }
	} catch { Write-Host "[vagrantupIgnoreWinRM.ps1] Invoke Exception thrown, $_"; exit 200 }
	
	if ($successCount -lt $successRequired) {
		$i++
		if ( $i -le $retries) {
			Write-Host "[winrmtest.ps1] Success count $successCount/$successRequired, retry WinRM ($i/$retries) wait $timeout seconds before retry ..."
			sleep $timeout
		} else {
			Write-Host "[winrmtest.ps1] WinRM Connection failed after $retries tries, exit with error code 201"
			exit 201
		}
	}
} # End of 'Do'
until (( $i -gt $retries) -or ($successCount -ge $successRequired))
if ($successCount -ge $successRequired) {
	Write-Host "[winrmtest.ps1] Success count $successCount/$successRequired."
}

Write-Host
Write-Host "[winrmtest.ps1] ---------- finish ----------"
Write-Host

# Clear the error array from any failed attempts
$error.clear()
