Write-Host
Write-Host "[CDAF.ps1] ---------- start ----------"
Write-Host

cd C:\vagrant
.\automation\cdEmulate.bat

.\automation\cdEmulate.bat clean

Write-Host
Write-Host "[CDAF.ps1] ---------- stop -----------"
Write-Host