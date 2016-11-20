
$scriptName = 'removeFile.ps1'
Write-Host
Write-Host "[$scriptName] Primarily for removing large media files after install"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$fileToRemove = $args[0]
if ($fileToRemove) {
    Write-Host "[$scriptName] fileToRemove : $fileToRemove"
} else {
    Write-Host "[$scriptName] fileToRemove not supplied! Exit with code 1"
    exit 1
}

if ( Test-Path $fileToRemove ) {
	write-host "[itemRemove] Delete $fileToRemove"
	Remove-Item $fileToRemove -Recurse -Force
	if(!$?) {exitWithCode "[itemRemove] Remove-Item $fileToRemove -Recurse -Force" }
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
