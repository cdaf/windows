function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
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

# Images shared via Vagrant cannot be mounted, so allow the option to copy from another location
$sourcePath = $args[1]
if ($sourcePath) {
    Write-Host "[$scriptName] sourcePath : $sourcePath"
    Write-Host
	executeExpression "Copy-Item `"$sourcePath`" `"$imagePath`""
}
Write-Host
executeExpression "Mount-DiskImage -ImagePath `"$imagePath`""
Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
