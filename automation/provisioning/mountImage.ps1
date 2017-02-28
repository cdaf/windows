# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
}

# This script is designed for media that is on a file share or web server, it will download the media to the
# local file system tehn mount it.
$scriptName = 'mountImage.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$imagePath = $args[0]
if ($imagePath) {
    Write-Host "[$scriptName] imagePath  : $imagePath"
} else {
    Write-Host "[$scriptName] imagePath not supplied, supply full path. Exiting!"
    exit 100
}

$sourcePath = $args[1]
if ($sourcePath) {
    Write-Host "[$scriptName] sourcePath : $sourcePath"
	$fallBack = $args[2]
	if ($fallBack) {
	    Write-Host "[$scriptName] fallBack   : $fallBack"
	} else {
		$fallBack = 'c:\.provision'
	    Write-Host "[$scriptName] fallBack   : not supplied defaulting to $fallBack"
	}
} else {
    Write-Host "[$scriptName] sourcePath : not supplied, dismounting $imagePath"
    Write-Host "[$scriptName] fallBack   : (not applicable when sourcePath not passed)"
}
Write-Host

# Obtain image and mount
if ($sourcePath) {
	if ($sourcePath -like 'http*') {	
	    Write-Host "[$scriptName] Attempt download from web server $sourcePath"
	    Write-Host
		$filename = $sourcePath.Substring($sourcePath.LastIndexOf("/") + 1)
		if ( Test-Path $imagePath ) {
			Write-Host "[scriptName.ps1] $imagePath exists, download not required"
		} else {
		
			$webclient = new-object system.net.webclient
			Write-Host "[$scriptName] $webclient.DownloadFile($sourcePath, $imagePath)"
			$webclient.DownloadFile($sourcePath, $imagePath)
			# TODO: fallback if download fails
		}
	} else {
	    Write-Host "[$scriptName] Attempt copy from file share $sourcePath"
	    Write-Host
		executeExpression "Copy-Item `"$sourcePath`" `"$imagePath`""
	}

	executeExpression "Mount-DiskImage -ImagePath `"$imagePath`""

# Dismount image
} else {

    Write-Host
	executeExpression "Dismount-DiskImage -ImagePath `"$imagePath`""

}
Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
