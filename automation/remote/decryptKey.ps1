Param (
  [string]$encryptedFile,
  [string]$thumbprint,
  [string]$location
)
$scriptName = $MyInvocation.MyCommand.Name

function throwError ($trapID, $message) {
    write-host "`n[$scriptName] $message`n" -ForegroundColor Red
	Write-Host "`n[$scriptName] ---- Diagnostic Info Start ----"
	Write-Host "[$scriptName] `$encryptedFile : $encryptedFile"
	Write-Host "[$scriptName] `$thumbprint    : $thumbprint"
	Write-Host "[$scriptName] `$location      : $location"
	if ($thumbprint) {
		if (-not ($location)) {
			$location = 'CurrentUser'
			Write-Host "[$scriptName] location, set default `$location to $location"
		}
		Write-Host "[$scriptName] Get-ChildItem -path `"Cert:\$location\My`""
		Get-ChildItem -path "Cert:\$location\My"
	}
	Write-Host "[$scriptName] ---- Diagnostic Info End ----`n"
	throw $trapID
}

if (! $encryptedFile) {
    throwError "DECRYPT_KEY_100" "Encrypted File (encrypted using Certificate or DSAPI) is required! Exiting" 
}

if (! (Test-Path $encryptedFile) ) {
	if (Test-Path "cryptLocal\$encryptedFile" ) {
		$encryptedFile = "cryptLocal\$encryptedFile"
	} else {
		if (Test-Path "cryptRemote\$encryptedFile" ) {
			$encryptedFile = "cryptRemote\$encryptedFile"
		} else {
		    throwError "DECRYPT_KEY_104" "Write-Host Encrypted file ($encryptedFile) not found"
		}
	}
}

# If a thumbprint is passed, decrypt file using PKI
if ($thumbprint) {

	try {
		# Check for certificate existance
		if (! $location) {
		    $location = 'LocalMachine'
		}
		if (!( Test-Path "Cert:\$location\My\$thumbprint" )) {
			if ($location -eq 'LocalMachine') {
			    $location = 'CurrentUser'
		    } else {
			    $location = 'LocalMachine'
			}
			if (!( Test-Path "Cert:\$location\My\$thumbprint" )) {
			    throwError "DECRYPT_KEY_107" "Unable to find thumbprint in either Cert:\CurrentUser\My\$thumbprint or Cert:\LocalMachine\My\$thumbprint."
		    }
		}

		# Attempted to open and decrypt
	    $object = Import-Clixml -Path $encryptedFile
		if (! $object) {
		    throwError "DECRYPT_KEY_102" "Unable to Import-Clixml $encryptedFile! Exit Code 102."
		}
		if (! $object.Key) {
		    throwError "DECRYPT_KEY_105" "Cannot retrieve private key for $encryptedFile! Exit Code 105."
		}
	    $cert = Get-Item -Path "Cert:\$location\My\$thumbprint" -ErrorAction Stop
		if (! $cert) {
		    throwError "DECRYPT_KEY_103" "Unable to open certificate Cert:\$location\My\$thumbprint"
		}
		if (! $cert.PrivateKey) {
			Write-Host "[$scriptName] Are you running as administrator? Elevation is required to retrieve private key!"
		    throwError "DECRYPT_KEY_106" "Unable to open private key for certificate Cert:\$location\My\$thumbprint"
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
$env:RESULT = $plain
return $plain
