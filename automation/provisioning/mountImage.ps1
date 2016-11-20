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

# Images shared via Vagrant cannot be mounted, so copy to image path
$sourcePath = $args[1]
if ($sourcePath) {

    Write-Host "[$scriptName] sourcePath : $sourcePath"
    Write-Host
	executeExpression "Copy-Item `"$sourcePath`" `"$imagePath`""
	executeExpression "Mount-DiskImage -ImagePath `"$imagePath`""

} else {

    Write-Host "[$scriptName] sourcePath not supplied, dismounting $imagePath"
    Write-Host
	executeExpression "Dismount-DiskImage -ImagePath `"$imagePath`""

}
Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
