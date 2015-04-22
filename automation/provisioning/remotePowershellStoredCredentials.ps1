$userCred = $args[0]
$outFile  = $args[1]
$testHost = $args[2]

# Capture (masked) password 
write-host "Enter password for $userCred"
read-host -assecurestring | convertfrom-securestring | out-file $outFile

# If test host is supplied, perform test
if ($testHost) {

	write-host "Test password for $userCred on $testHost"
	# Decrypt the password to a variable
	$password = get-content $outFile | convertto-securestring

	# Instantiate a Credential object
	$cred = New-Object System.Management.Automation.PSCredential ($userCred, $password )

	# Open a session with the credentials
	enter-pssession  $testHost -credential $cred

	# Verify user in remote session
	whoami
	exit
}
