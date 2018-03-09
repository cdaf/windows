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
	$mediaDir = $env:temp
	$fullpath = $mediaDir + '\' + $file
	return $fullpath
}

cmd /c "exit 0"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptName = 'installApacheAnt.ps1'

Write-Host "`n[$scriptName] ---------- start ----------"
$version = $args[0]
if ( $version ) {
	Write-Host "[$scriptName] version               : $version"
} else {
	$version = '1.9.10'
	Write-Host "[$scriptName] version               : $version (default)"
}

$mediaDir = $args[1]
if ( $mediaDir ) {
	Write-Host "[$scriptName] mediaDirectory        : $mediaDir"
} else {
	$mediaDir = 'C:\.provision'
	Write-Host "[$scriptName] mediaDirectory        : $mediaDir (default)"
}

$destinationInstallDir = $args[2]
if ( $destinationInstallDir ) {
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir"
} else {
	$destinationInstallDir = 'c:\apache'
	Write-Host "[$scriptName] destinationInstallDir : $destinationInstallDir (default)"
}

Write-Host

# The installation directory for Ant, the script will create this
$target = 'apache-ant-' + $version
$file = $target + "-bin.zip"
$installFile = $mediaDir + '\' + $file
Write-Host
if ( Test-Path $installFile ) {
	Write-Host "[$scriptName] Source media found ($installFile)"
} else {
	Write-Host "[$scriptName] $file does not exist in $mediaDir, listing contents"
	try {
		Get-ChildItem $mediaDir | Format-Table name
	    if(!$?) { $installFile = listAndContinue }
	} catch { $installFile = listAndContinue }

	Write-Host "[$scriptName] Attempt download"
	$uri = 'http://www-eu.apache.org/dist/ant/binaries/' + $file
	executeExpression "(New-Object System.Net.WebClient).DownloadFile('$uri', '$installFile')"
}

Write-Host "[$scriptName] ant media is packaged as a directory (apache-ant-$version)"
if ( Test-Path $destinationInstallDir\$target ) {
	Write-Host "`n[$scriptName] Target ($destinationInstallDir\$target) exists, remove first"
	executeExpression "Remove-Item -Recurse -Force $destinationInstallDir\$target"
}

Write-Host
if ( Test-Path $destinationInstallDir ) {
	Write-Host "[$scriptName] destinationInstallDir ($destinationInstallDir) exists"
} else { 
	Write-Host "[$scriptName] Create destinationInstallDir ($destinationInstallDir)"
	executeExpression "New-Item -path $destinationInstallDir -type directory"
}

executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory('$installFile', '$destinationInstallDir')"

Write-Host "`n[$scriptName] Add to PATH"
$pathEnvVar=[System.Environment]::GetEnvironmentVariable("PATH","Machine")
executeExpression "[System.Environment]::SetEnvironmentVariable('PATH', '$pathEnvVar' + ';$destinationInstallDir\apache-ant-$version\bin', 'Machine')"

# Reload the path (without logging off and back on)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

$versionTest = cmd /c ant -version 2`>`&1
if ($versionTest -like '*not recognized*') {
	Write-Host "  Apache Ant install failed!": exit 23700
} else {
	$array = $versionTest.split(" ")
	Write-Host "  Apache Ant              : $($array[3])"
}

Write-Host "`n[$scriptName] ---------- stop -----------`n"
$error.clear()
exit 0