$scriptName = 'addHOSTS.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$ip = $args[0]
if ($ip) {
    Write-Host "[$scriptName] ip      : $ip"
} else {
    Write-Host "[$scriptName] ip no supplied"
    exit 100
}

$address = $args[1]
if ($address) {
    Write-Host "[$scriptName] address : $address"
} else {
    Write-Host "[$scriptName] address not supplied"
    exit 101
}

$hosts = "$env:windir\System32\drivers\etc\hosts"
Add-Content $hosts "`n$ip $address"

Write-Host "[$scriptName] $hosts content"
cat $hosts

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
