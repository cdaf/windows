Write-Host
Write-Host "[CredSSP-Client.ps1] ---------- start ----------"

Write-Host "[CredSSP-Client.ps1] Enable-WSManCredSSP -Role client -DelegateComputer * -Force"
Enable-WSManCredSSP -Role client -DelegateComputer * -Force

Write-Host "[CredSSP-Client.ps1] ---------- stop -----------"
Write-Host