function itemRemove ($itemPath) { 
# If item exists, and is not a directory, remove read only and delete, if a directory then just delete
	if ( Test-Path $itemPath ) {
		write-host "[itemRemove] Delete $itemPath"
		Remove-Item $itemPath -Recurse -Force
		if(!$?) {exitWithCode "[itemRemove] Remove-Item $itemPath -Recurse -Force" }
	}
}

$scriptName = 'removeFile.ps1'
Write-Host
Write-Host "[$scriptName] Primarily for removing large media files after install"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$fileToRemove = $args[0]
if ($fileToRemove) {
    Write-Host "[$scriptName] fileToRemove : $fileToRemove"
} else {
	$fileToRemove = 'sky.net'
    Write-Host "[$scriptName] fileToRemove : $fileToRemove (default)"
}

itemRemove $fileToRemove

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
