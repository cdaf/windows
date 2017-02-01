function throwError ($trapID, $message) {
    write-host;write-host "[$scriptName] $message" -ForegroundColor Red;write-host
	throw $trapID
}

$scriptName = $MyInvocation.MyCommand.Name
$encryptedFile = $args[0]
$thumbprint    = $args[1]

#Write-Host "[$scriptName] `$encryptedFile = $encryptedFile"
#Write-Host "[$scriptName] `$thumbprint = $thumbprint"

if (! $encryptedFile) {
    throwError "DECRYPT_KEY_100" "Encrypted File (encrypted using Certificate or DSAPI) is required! Exiting" 
}

if (! (Test-Path $encryptedFile) ) {
    throwError "DECRYPT_KEY_104" "Write-Host Encrypted file ($encryptedFile) not found"
}

if ($thumbprint) {

	# If a thumbprint is passed, decrypt file using RSA certificate
	try {
	    $object = Import-Clixml -Path $encryptedFile
		if (! $object) {
		    throwError "DECRYPT_KEY_102" "Unable to Import-Clixml $encryptedFile! Exit Code 102."
		}
		if (! $object.Key) {
		    throwError "DECRYPT_KEY_105" "Cannot retrieve private key for $encryptedFile! Exit Code 105."
		}
	    $cert = Get-Item -Path Cert:\CurrentUser\My\$thumbprint -ErrorAction Stop
		if (! $cert) {
		    throwError "DECRYPT_KEY_103" "Unable to open certificate Cert:\CurrentUser\My\$thumbprint"
		}
		if (! $cert.PrivateKey) {
			Write-Host "[$scriptName] Are you running as administrator? Elevation is required to retrieve private key!"
		    throwError "DECRYPT_KEY_106" "Unable to open private key for certificate Cert:\CurrentUser\My\$thumbprint"
		}
		# Write-Host "[$scriptName] `$object = $object"
	    $key = $cert.PrivateKey.Decrypt($object.Key, $true)
		if (! $cert) {
		    throwError "DECRYPT_KEY_104" "Unable to decrypt using private key."
		}
		# Write-Host "[$scriptName] `$key = $key"
	    $retrievedString = $object.Payload | ConvertTo-SecureString -Key $key
		$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($retrievedString))
	} catch {
		throw
	} finally {
	    if ($null -ne $key) { [array]::Clear($key, 0, $key.Length) }
	}

} else {

	# Decrypt using DSAPI
	$retrievedString = Get-Content $encryptedFile | ConvertTo-SecureString
	$plain = (New-Object System.Management.Automation.PSCredential 'N/A', $retrievedString).GetNetworkCredential().Password
}

#Write-Host "[$scriptName] `$plain = $plain"
return $plain
