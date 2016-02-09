$encryptedFile = $args[0]
$thumbprint    = $args[1]

# Output File (plain text or XML depending on method) must be supplioed
if (! $encryptedFile) {
    Write-Host "[$scriptName] Encrypted file not passed! Exiting"
    exit 100
}

if ($thumbprint) {

	# If a thumbprint is passed, decrypt file using RSA certificate
	try {
	    $object = Import-Clixml -Path $encryptedFile
	
	    $cert = Get-Item -Path Cert:\CurrentUser\My\$thumbprint -ErrorAction Stop
	
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
