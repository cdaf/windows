$packagePath = $args[0]
$packageFile = $args[1]

$scriptName = "extract.ps1"

cd $packagePath

$packageCommand = "& 7za.exe x $packageFile.zip -o$packageFile -y"
Invoke-Expression $packageCommand
$exitcode = $LASTEXITCODE
if ( $exitcode -gt 0 ) { 

	Write-Host
	Write-Host "[$scriptName] Package Extraction (Zip) failed with exit code = $exitcode" -ForegroundColor Red
	throw "Package Extraction (Zip) failed with exit code = $exitcode" 

} else {

	Write-Host
	Write-Host "[$scriptName (remote)] Package Extraction Successful" -ForegroundColor Green

}
