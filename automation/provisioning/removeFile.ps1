
$scriptName = 'removeFile.ps1'
Write-Host "`n[$scriptName] Primarily for removing large media files after install"
Write-Host "`n[$scriptName] ---------- start ----------"
$fileToRemove = $args[0]
if ($fileToRemove) {
    Write-Host "[$scriptName] fileToRemove : $fileToRemove"
} else {
    Write-Host "[$scriptName] fileToRemove not supplied! Exit with `$LASTEXITCODE 1"
    exit 1
}

if ( Test-Path $fileToRemove ) {
	write-host "[itemRemove] Delete $fileToRemove"
	Remove-Item $fileToRemove -Recurse -Force
	if(!$?) {
	    Write-Host "[$scriptName] DELETE_EXCEPTION Remove-Item $fileToRemove -Recurse -Force"
	    Write-Host "[$scriptName]   Exit with `$LASTEXITCODE 2"
	    exit 2
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------"
