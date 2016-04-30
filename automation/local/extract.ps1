Add-Type -AssemblyName System.IO.Compression.FileSystem

$packagePath = $args[0]
$packageFile = $args[1]

$scriptName = "extract.ps1"

[System.IO.Compression.ZipFile]::ExtractToDirectory("$packagePath\$packageFile.zip", "$packagePath\$packageFile")
$exitcode = $LASTEXITCODE
if ( $exitcode -gt 0 ) { 

	Write-Host
	Write-Host "[$scriptName (remote)] Package Extraction (Zip) failed with exit code = $exitcode" -ForegroundColor Red
	throw "Package Extraction (Zip) failed with exit code = $exitcode" 

} else {

	foreach ($item in (Get-ChildItem -Path $packagePath\$packageFile)) {
		Write-Host "[$scriptName (remote)]    --> $item"
	}

	Write-Host
	Write-Host "[$scriptName (remote)] Package Extraction Successful" -ForegroundColor Green

}
