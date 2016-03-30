$scriptName     = 'SysPrep.ps1'

Write-Host
Write-Host "[$scriptName] System Preparation (sets SID)"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"

Write-Host "[$scriptName] C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /quit /quiet"
C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /quit /quiet

Write-Host "[$scriptName] ---------- stop -----------"
Write-Host