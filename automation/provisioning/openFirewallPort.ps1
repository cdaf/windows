
$scriptName = 'openFirewallPort.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$dbName = $args[0]
if ($dbName) {
    Write-Host "[$scriptName] dbName     : $dbName"
} else {
    Write-Host "[$scriptName] dbName not supplied, exiting with code 100"
    exit 100
}

New-NetFirewallRule -DisplayName "SQL Server" -Direction Inbound –Protocol TCP –LocalPort 1433 -Action allow
Set-NetFirewallProfile -DefaultInboundAction Block -DefaultOutboundAction Allow -NotifyOnListen True -AllowUnicastResponseToMulticast True

Write-Host
Write-Host "[$scriptName] Created $dbName on $dbhost\$dbinstance at $createdDate."

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
