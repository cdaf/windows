$scriptName = 'mkdir.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
Write-Host
$directoryName = $args[0]
if ($directoryName) {
    Write-Host "[$scriptName] directoryName : $directoryName"
} else {
    Write-Host "[$scriptName] directoryName not supplied, exiting!"
    exit 100
}

if ( Test-Path $directoryName ) {
	Write-Host "[$scriptName] Directory $directoryName already exists, no action attempted."
} else {
	Write-Host "[$scriptName] mkdir $directoryName"
	mkdir $directoryName
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host