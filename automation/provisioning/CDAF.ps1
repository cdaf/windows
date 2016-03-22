Write-Host
Write-Host "[CDAF.ps1] ---------- start ----------"
Write-Host

Write-Host "[CDAF.ps1] cd C:\vagrant"
cd C:\vagrant

Write-Host "[CDAF.ps1] .\automation\cdEmulate.bat"
.\automation\cdEmulate.bat
$exitcode = $LASTEXITCODE
if ( $exitcode -gt 0 ) { 
    Write-Host
    Write-Host "[$scriptName] Emulation failed with LASTEXITCODE = $exitcode" -ForegroundColor Red
    throwErrorlevel "DOS_TERM" $exitcode
}

Write-Host "[CDAF.ps1] .\automation\cdEmulate.bat clean"
.\automation\cdEmulate.bat clean
$exitcode = $LASTEXITCODE
if ( $exitcode -gt 0 ) { 
    Write-Host
    Write-Host "[$scriptName] Emulation  (clean) failed with LASTEXITCODE = $exitcode" -ForegroundColor Red
    throwErrorlevel "DOS_TERM" $exitcode
}

Write-Host
Write-Host "[CDAF.ps1] ---------- stop -----------"
Write-Host