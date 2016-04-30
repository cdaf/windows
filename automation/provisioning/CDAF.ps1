$scriptName = 'CDAF.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
Write-Host

Write-Host "[$scriptName] cd C:\vagrant"
cd C:\vagrant

Write-Host "[$scriptName] .\automation\cdEmulate.bat"
& .\automation\cdEmulate.bat
if(!$?){
    write-host
    write-host "[$scriptName] cdEmulate.bat failed, returning errorlevel (-1)" -ForegroundColor Red
    write-host
    $host.SetShouldExit(-1)
    exit
}

Write-Host "[$scriptName] .\automation\cdEmulate.bat clean"
& .\automation\cdEmulate.bat clean
if(!$?){
    write-host
    write-host "[$scriptName] cdEmulate.bat clean failed, returning errorlevel (-1)" -ForegroundColor Red
    write-host
    $host.SetShouldExit(-1)
    exit
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host