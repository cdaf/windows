$encryptedFile = $args[0]
$thumbprint    = $args[1]

if (! $encryptedFile) {
    Write-Host "[$scriptName] Encrypted File (encrypted using Certificate or DSAPI) is required! Exiting"
    exit 100
}

if ($thumbprint) {

	# If a thumbprint is passed, decrypt file using RSA certificate
	try {
	    $object = Import-Clixml -Path $encryptedFile
		if (! $object) {
		    Write-Host "[$scriptName] Unable to Import-Clixml $encryptedFile! Exit Code 102."
		    exit 102
		}
	    $cert = Get-Item -Path Cert:\CurrentUser\My\$thumbprint -ErrorAction Stop
		if (! $cert) {
		    Write-Host "[$scriptName] Unable to open certificate Cert:\CurrentUser\My\$thumbprint"
		    exit 101
		}
	    $key = $cert.PrivateKey.Decrypt($object.Key, $true)
	    $retrievedString = $object.Payload | ConvertTo-SecureString -Key $key
		$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($retrievedString))
	}
	finally
	{
	    if ($null -ne $key) { [array]::Clear($key, 0, $key.Length) }
	}

} else {

	# Decrypt using DSAPI
	$retrievedString = Get-Content $encryptedFile | ConvertTo-SecureString
	$plain = (New-Object System.Management.Automation.PSCredential 'N/A', $retrievedString).GetNetworkCredential().Password
}
return $plain
