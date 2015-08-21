$outFile  = $args[0]

# If output file is not supplied, use default

if ($outFile) {
    Write-Host "[$scriptName] Output File : $outFile"
} else {
    $outFile = ".\crypt.txt"
    Write-Host "[$scriptName] Output File not passed, default to $outFile"
}

# Capture (masked) value 
write-host
write-host "Enter value to encrypt : " -NoNewline
read-host -assecurestring | convertfrom-securestring | out-file $outFile

# Retrieve the value for verification purposes
$secure = Get-Content $outFile | ConvertTo-SecureString
$plain = (New-Object System.Management.Automation.PSCredential 'N/A', $secure).GetNetworkCredential().Password
write-host
write-host "Encrypt/Decrypt test to `$plain"
write-host
