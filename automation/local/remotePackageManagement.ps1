$packagePath = $args[0]
$packageFile = $args[1]

$scriptName = "packageTest.ps1"

# If this script has started, then the PowerShell session is valid
Write-Host "[$scriptName (remote)] Connection test Successfull" -ForegroundColor Green

if ( ! ( Test-Path $packagePath )) {
	Write-Host "[$scriptName (remote)] Target path does not exit, attempt to create $packagePath"
	New-Item -Path "$packagePath" -ItemType directory
}

cd $packagePath
$timeStamp = $(get-date -f yyyy-MM-dd-hhmmss)
$packageFileName = $packageFile + ".zip"

if ( Test-Path $packageFileName ) {

	Write-Host
	Write-Host "[$scriptName (remote)] Package file ($packageFile.zip) exists rename:"
	Write-Host "[$scriptName (remote)]   $packageFileName --> $packageFile-$timeStamp.zip"
	Move-Item $packageFileName $packageFile-$timeStamp.zip

} else {

	Write-Host
	Write-Host "[$scriptName (remote)] Not a re-run, purge landing directory ($(pwd))."
	Remove-Item * -Recurse -Force

}

if ( Test-Path $packageFile ) {
	Write-Host
	Write-Host "[$scriptName (remote)] Extracted Package directory ($packageFile) exists rename:"
	Write-Host "[$scriptName (remote)]   $packageFile --> $packageFile-$timeStamp"
	Move-Item $packageFile $packageFile-$timeStamp
}
