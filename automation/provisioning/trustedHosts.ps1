$trustedHosts = $args[0]

# Output File (plain text or XML depending on method) must be supplioed
if ($trustedHosts) {
    Write-Host "[$scriptName] trustedHosts : $trustedHosts"
} else {
    Write-Host "[$scriptName] trustedHosts not passed! Exiting"
    exit 100
}

Write-Host
Write-Host "[provision.ps1] Add the trustedHosts ($trustedHosts) as a trusted hosts for Remote Powershell"
Set-WSManInstance -ResourceURI winrm/config/client -ValueSet @{TrustedHosts=$trustedHosts}
