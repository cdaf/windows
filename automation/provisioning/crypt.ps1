Param (
  [string]$outFile,
  [string]$thumbprint,
  [string]$value,
  [string]$location
)

$scriptName = 'crypt.ps1'
Write-Host "`n[$scriptName] ---------- start ----------"

if ($outFile) {
    Write-Host "[$scriptName] outFile    : $outFile"
} else {
	write-host "Enter the output file    : " -NoNewline
	$outFile = Read-host
}

if ($thumbprint) {
    Write-Host "[$scriptName] thumbprint : $thumbprint"
} else {
    Write-Host "[$scriptName] thumbprint : (not supplied, will use DPAPI)"
}

if ($value) {
    Write-Host "[$scriptName] value      : *************************"
    $secureString = ConvertTo-SecureString $value -AsPlainText -Force
} else {
	# Capture (masked) value 
	write-host
	write-host "Enter value to encrypt   : " -NoNewline
	$secureString = Read-host -AsSecureString
}

if (! $location) {
    $location = 'CurrentUser'
}

Write-Host "`n[$scriptName] Available certificates"
Get-ChildItem -Path "Cert:\$location\My" | format-table

if ($thumbprint) {

	# If a thumbprint is passed, create the encrypted file using RSA certificate
 	# Test certificate thumbprint
	# add54aca2ec46ec697e4c55ece052807725a4834

	try	{
			
	    # Generate our new 32-byte AES key.  I don't recommend using Get-Random for this; the System.Security.Cryptography namespace
	    # offers a much more secure random number generator.
	
	    $key = New-Object byte[](32)
	    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
	    $rng.GetBytes($key)
	
	    $encryptedString = ConvertFrom-SecureString -SecureString $secureString -Key $key
	
	    $cert = Get-Item -Path "Cert:\$location\My\$thumbprint" -ErrorAction Stop
		if($Cert.HasPrivateKey -eq $False -or $Cert.PrivateKey -eq $null)
		    {
		        Write-Error "The supplied certificate does not contain a private key, or it could not be accessed."
		        exit 101
		    }
	
	    $encryptedKey = $cert.PublicKey.Key.Encrypt($key, $true)
	
	    $object = New-Object psobject -Property @{
	        Key = $encryptedKey
	        Payload = $encryptedString
	    }
	
	    $object | Export-Clixml $outFile
	
	}
	finally
	{
	    if ($null -ne $key) { [array]::Clear($key, 0, $key.Length) }
	}
	
    # Decrypt to verify
	try {
	    $object = Import-Clixml -Path $outFile
	
	    $cert = Get-Item -Path "Cert:\$location\My\$thumbprint" -ErrorAction Stop
	
	    $key = $cert.PrivateKey.Decrypt($object.Key, $true)
	
	    $retrievedString = $object.Payload | ConvertTo-SecureString -Key $key
		$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($retrievedString))
	    
	}
	finally
	{
	    if ($null -ne $key) { [array]::Clear($key, 0, $key.Length) }
	}

} else {

	# If a thumbprint is not passed, encrypt using Data Protection API 
	$secureString | convertfrom-securestring | out-file $outFile
	
	# Retrieve the value for verification purposes
	$retrievedString = Get-Content $outFile | ConvertTo-SecureString
	$plain = (New-Object System.Management.Automation.PSCredential 'N/A', $retrievedString).GetNetworkCredential().Password
}

if ( $plain ) {
	write-host "`nEncrypt/Decrypt test (to `$plain) successful.`n"
} else {
	write-host "`nEncrypt/Decrypt failure!.`n"
	exit 56
}

Write-Host "`n[$scriptName] ---------- finish ----------"
