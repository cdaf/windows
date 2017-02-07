Write-Host
Write-Host "[winrmtest.ps1] ---------- start ----------"
Write-Host

if ( $args[0] ) {
	$vmHost = $args[0]
	Write-Host "[winrmtest.ps1] vmHost          : $vmHost"
} else {
	Write-Host "[winrmtest.ps1] VM host not passed, exit with error code 100."; exit 100
}
if ( $args[1] ) {
	$username = $args[1]
	Write-Host "[winrmtest.ps1] username        : $username"
} else {
	Write-Host "[winrmtest.ps1] Username not passed, exit with error code 101."; exit 101
}

if ( $args[2] ) {
	$userpass = $args[2]
	Write-Host "[winrmtest.ps1] userpass        : ***********"
} else {
	Write-Host "[winrmtest.ps1] Password not passed, exit with error code 102."; exit 102
}

if ( $args[3] ) {
	$successRequired = $args[3]
} else {
	$successRequired = 2
}

Write-Host "[winrmtest.ps1] successRequired : $successRequired"
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
$count = 20
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
		if ( $i -le $count) {
			Write-Host "[winrmtest.ps1] Success count $successCount/$successRequired, retry WinRM ($i/$count) wait $timeout seconds before retry ..."
			sleep $timeout
		} else {
			Write-Host "[winrmtest.ps1] WinRM Connection failed after $count tries, exit with error code 201"
			exit 201
		}
	}
} # End of 'Do'
until (( $i -gt $count) -or ($successCount -ge $successRequired))
if ($successCount -ge $successRequired) {
	Write-Host "[winrmtest.ps1] Success count $successCount/$successRequired."
}

Write-Host
Write-Host "[winrmtest.ps1] ---------- finish ----------"
Write-Host

# Clear the error array from any failed attempts
$error.clear()
