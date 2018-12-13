Param (
	[string]$soapui_version,
	[string]$mediaDirectory,
	[string]$destinationInstallDir,
	[string]$proxy
)

cmd /c "exit 0"
$scriptName = 'installSoapUI.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

# Cater for media directory being inaccesible, i.e. Vagrant/Hyper-V
function listAndContinue {
	Write-Host "[$scriptName] Error accessing cache falling back to `$env:temp"
	$mediaDirectory = $env:temp
	$fullpath = $mediaDirectory + '\' + $file
	return $fullpath
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

Write-Host "`n[$scriptName] ---------- start ----------"
if ( $soapui_version ) {
	Write-Host "[$scriptName] soapui_version        : $soapui_version"
} else {
	$soapui_version = '5.2.1'
	Write-Host "[$scriptName] soapui_version        : $soapui_version (default)"
}

if ( $mediaDirectory ) {
	Write-Host "[$scriptName] mediaDirectory        : $mediaDirectory"
} else {
	$mediaDirectory = 'C:\.provision'
	Write-Host "[$scriptName] mediaDirectory        : $mediaDirectory (default)"
}

if ( $destinationInstallDir ) {
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir"
} else {
	$destinationInstallDir = 'c:\soapui'
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir (default)"
}

if ( Test-Path $mediaDirectory ) {
	Write-Host "`n[$scriptName] $mediaDirectory exists"
} else {
	Write-Host "`n[$scriptName] $(mkdir $mediaDirectory) created"
}

if ($proxy) {
    Write-Host "[$scriptName] proxy                 : $proxy`n"
    executeExpression "[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('$proxy')"
} else {
    Write-Host "[$scriptName] proxy                 : (not supplied)"
}

# The installation directory for SoapUI, the script will create this
$target = 'soapui-' + $soapui_version
$mediaFileName = $target + "-windows-bin.zip"
if ( Test-Path $mediaDirectory\$mediaFileName ) {
	Write-Host "`n[$scriptName] Source media found ($mediaDirectory\$mediaFileName)"
} else { 
	Write-Host "`n[$scriptName] $mediaFileName does not exist in $mediaDirectory, listing contents"
	try {
		Get-ChildItem $mediaDirectory | Format-Table name
	    if(!$?) { $installFile = listAndContinue }
	} catch { $installFile = listAndContinue }

	Write-Host "[$scriptName] Attempt download"
	$uri = "http://smartbearsoftware.com/distrib/soapui/${soapui_version}/" + $mediaFileName
	executeExpression "(New-Object System.Net.WebClient).DownloadFile('$uri', '$mediaDirectory\$mediaFileName')"
}

Write-Host "[$scriptName] Soapui media is packaged as a directory (soapui-$soapui_version)"
if ( Test-Path $destinationInstallDir\$target ) {
	Write-Host "`n[$scriptName] Target ($destinationInstallDir\$target) exists, remove first"
	executeExpression "Remove-Item -Recurse -Force $destinationInstallDir\$target"
}

if ( Test-Path $destinationInstallDir ) {
	Write-Host "`n[$scriptName] destinationInstallDir ($destinationInstallDir) exists"
} else { 
	Write-Host "`n[$scriptName] Create destinationInstallDir ($destinationInstallDir)"
	executeExpression "New-Item -path $destinationInstallDir -type directory"
}

executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory(`"$mediaDirectory\$mediaFileName`", `"$destinationInstallDir`")"

Write-Host "`n[$scriptName] Add to PATH"
$pathEnvVar=[System.Environment]::GetEnvironmentVariable("PATH","Machine")
executeExpression "[System.Environment]::SetEnvironmentVariable('PATH', '$pathEnvVar' + ';$destinationInstallDir\$target\bin', 'Machine')"

Write-Host "`n[$scriptName] ---------- stop -----------`n"
