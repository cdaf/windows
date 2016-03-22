Write-Host
Write-Host "[trustedHosts.ps1] ---------- start ----------"
$trustedHosts = $args[0]

# Output File (plain text or XML depending on method) must be supplioed
if ($trustedHosts) {
    Write-Host "[trustedHosts.ps1] trustedHosts : $trustedHosts"
} else {
    Write-Host "[trustedHosts.ps1] trustedHosts not passed! Exiting"
    exit 100
}

Write-Host
Write-Host "[trustedHosts.ps1] Add the trustedHosts ($trustedHosts) as a trusted hosts for Remote Powershell"
Set-WSManInstance -ResourceURI winrm/config/client -ValueSet @{TrustedHosts=$trustedHosts}

Write-Host
Write-Host "[trustedHosts.ps1] ---------- stop -----------"
Write-Host