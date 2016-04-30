Write-Host
Write-Host "[CDAF_Desktop_Certificate.ps1] ---------- start ----------"
Write-Host
Write-Host "[CDAF_Desktop_Certificate.ps1] Requires elevated privilages"
Write-Host "[CDAF_Desktop_Certificate.ps1] Import the certificate /vagrant/automation/provisioning/CDAF_Desktop_Certificate.pfx"
$certAsBytes = [System.IO.File]::ReadAllBytes('/vagrant/automation/provisioning/CDAF_Desktop_Certificate.pfx')
$pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
$pfx.import($certAsBytes, 'password', 'Exportable,PersistKeySet')
Write-Host
Write-Host "[CDAF_Desktop_Certificate.ps1] Access the store (My/CurrentUser)"
$store = new-object System.Security.Cryptography.X509Certificates.X509Store('My','CurrentUser')
$store.open('MaxAllowed')
$store.add($pfx)
$store.close()
Write-Host
Write-Host "[CDAF_Desktop_Certificate.ps1] Import complete"
Get-ChildItem -path cert:\CurrentUser\My
Write-Host
Write-Host "[CDAF_Desktop_Certificate.ps1] ---------- stop -----------"
Write-Host