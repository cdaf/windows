function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	# Execute expression and trap powershell exceptions
	try {
	    Invoke-Expression $expression
	    if(!$?) {
			Write-Host; Write-Host "[$scriptName] Expression failed without an exception thrown. Exit with code 1."; Write-Host 
			exit 1
		}
	} catch {
		Write-Host; Write-Host "[$scriptName] Expression threw exception. Exit with code 2, exception message follows ..."; Write-Host 
		Write-Host "[$scriptName] $_"; Write-Host 
		exit 2
	}
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
