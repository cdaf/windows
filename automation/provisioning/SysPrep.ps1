$scriptName = 'SysPrep.ps1'

Write-Host
Write-Host "[$scriptName] System Preparation (sets SID)"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$unattendFile = $args[0]
if ($unattendFile) {
    Write-Host "[$scriptName] unattendFile : $unattendFile"
} else {
    Write-Host "[$scriptName] unattendFile not supplied, halt!"
    exit 100
}

$completeAction = $args[1]
if ($completeAction) {
	$completeAction = 'reboot'
    Write-Host "[$scriptName] completeAction : $completeAction (default, choices shutdown, quit or reboot)"
} else {
    Write-Host "[$scriptName] completeAction : $completeAction (choices shutdown, quit or reboot)"
    exit 100
}

Write-Host "[$scriptName] C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /quiet /unattend:$unattendFile /$completeAction"
$process = Start-Process -FilePath 'C:\Windows\System32\Sysprep\Sysprep.exe' -ArgumentList "/generalize /oobe /quiet /unattend:$unattendFile /$completeAction" -PassThru -Wait

Write-Host "[$scriptName] ---------- stop -----------"
Write-Host