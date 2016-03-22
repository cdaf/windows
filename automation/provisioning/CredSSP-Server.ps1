Write-Host
Write-Host "[CredSSP-Server.ps1] ---------- start ----------"

Write-Host "[CredSSP-Server.ps1] Enable-WSManCredSSP -Role server -Force"
Enable-WSManCredSSP -Role server -Force

Write-Host "[CredSSP-Server.ps1] ---------- stop -----------"
Write-Host