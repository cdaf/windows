$scriptName = 'Restart.ps1'

Write-Host
Write-Host "[$scriptName] If using a provisioner, only use this if releasing control of the host"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$delay = $args[0]
if ($delay) {
    Write-Host "[$scriptName] delay (seconds) : $delay"
} else {
	$delay = 2
    Write-Host "[$scriptName] delay (seconds) : $delay (default)"
}

Write-Host "[$scriptName] & shutdown /r /t $delay"
& shutdown /r /t $delay

Write-Host "[$scriptName] ---------- stop -----------"
Write-Host