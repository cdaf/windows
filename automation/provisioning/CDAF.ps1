$scriptName = 'CDAF.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
Write-Host

Write-Host "[$scriptName] cd C:\vagrant"
cd C:\vagrant

Write-Host "[$scriptName] .\automation\cdEmulate.bat"
.\automation\cdEmulate.bat
$exitcode = $LASTEXITCODE
if ( $exitcode -gt 0 ) { 
    Write-Host
    Write-Host "[$scriptName] Emulation failed with LASTEXITCODE = $exitcode" -ForegroundColor Red
    throwErrorlevel "DOS_TERM" $exitcode
}

Write-Host "[$scriptName] .\automation\cdEmulate.bat clean"
.\automation\cdEmulate.bat clean
$exitcode = $LASTEXITCODE
if ( $exitcode -gt 0 ) { 
    Write-Host
    Write-Host "[$scriptName] Emulation  (clean) failed with LASTEXITCODE = $exitcode" -ForegroundColor Red
    throwErrorlevel "DOS_TERM" $exitcode
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host