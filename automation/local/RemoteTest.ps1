$pid = $args[0]

$scriptName = "RemoteTest.ps1"

Write-Host ""
Write-Host "[$scriptName (remote)] Remote Connection Test Starting, called from PID $pid" -ForegroundColor Green
Write-Host ""

$currentDirectory = Get-Location 
$localMachine = hostname
$userID = whoami

Write-Host "[Task0.ps1 (remote)] Running as $userID on $localMachine in $currentDirectory, PSVersionTable details :"

$PSVersionTable