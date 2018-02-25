# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptName = 'installSoapUI.ps1'

Write-Host
Write-Host "[$scriptName] ---------- start ----------"

$soapui_version = $args[0]
if ( $soapui_version ) {
	Write-Host "[$scriptName] soapui_version         : $soapui_version"
} else {
	$soapui_version = '5.4.0'
	Write-Host "[$scriptName] soapui_version         : $soapui_version (default)"
}

$mediaDirectory = $args[1]
if ( $mediaDirectory ) {
	Write-Host "[$scriptName] mediaDirectory        : $mediaDirectory"
} else {
	$mediaDirectory = 'c:\vagrant\.provision'
	Write-Host "[$scriptName] mediaDirectory        : $mediaDirectory (default)"
}

$destinationInstallDir = $args[2]
if ( $destinationInstallDir ) {
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir"
} else {
	$destinationInstallDir = 'c:\soapui'
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir (default)"
}

Write-Host

# The installation directory for SoapUI, the script will create this
$target = 'soapui-' + $soapui_version
$mediaFileName = $target + "-windows-bin.zip"
Write-Host
if ( Test-Path $mediaDirectory\$mediaFileName ) {
	Write-Host "[$scriptName] Source media found ($mediaDirectory\$mediaFileName)"
} else { 
	Write-Host "[$scriptName] Source media ($mediaDirectory\$mediaFileName) NOT FOUND, exiting with code 1!"
	exit 1
}

Write-Host "[$scriptName] Soapui media is packaged as a directory (soapui-$soapui_version)"
if ( Test-Path $destinationInstallDir\$target ) {
	Write-Host
	Write-Host "[$scriptName] Target ($destinationInstallDir\$target) exists, remove first"
	executeExpression "Remove-Item -Recurse -Force $destinationInstallDir\$target"
}

Write-Host
if ( Test-Path $destinationInstallDir ) {
	Write-Host "[$scriptName] destinationInstallDir ($destinationInstallDir) exists"
} else { 
	Write-Host "[$scriptName] Create destinationInstallDir ($destinationInstallDir)"
	executeExpression "New-Item -path $destinationInstallDir -type directory"
}

executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory(`"$mediaDirectory\$mediaFileName`", `"$destinationInstallDir`")"

Write-Host
#Write-Host " Add Maven to PATH"
#$pathEnvVar=[System.Environment]::GetEnvironmentVariable("PATH","Machine")
#executeExpression "[System.Environment]::SetEnvironmentVariable('PATH', `"$pathEnvVar`" + `";$destinationInstallDir\soapui-$soapui_version\bin`", 'Machine')"
Write-Host "--------------Soap UI Extraction complete------------"
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host
