$scriptName = 'SysPrep.ps1'

Write-Host
Write-Host "[$scriptName] System Preparation (sets SID)"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"

Write-Host "[$scriptName] C:\Windows\System32\Sysprep\Sysprep.exe /generalize /quit /quiet"
$process = Start-Process -FilePath 'C:\Windows\System32\Sysprep\Sysprep.exe' -ArgumentList '/generalize /quit /quiet' -PassThru -Wait

Write-Host "[$scriptName] ---------- stop -----------"
Write-Host