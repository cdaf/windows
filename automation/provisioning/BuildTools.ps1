$scriptName = 'BuildTools.ps1'
$versionChoices = '14' 
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$version = $args[0]
if ($version) {
    Write-Host "[$scriptName] version     : $version"
} else {
	$version = '14'
    Write-Host "[$scriptName] version     : $version (default, choices $versionChoices)"
}

$mediaDir = $args[1]
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir    : $mediaDir"
} else {
	$mediaDir = 'C:\vagrant\.provision'
    Write-Host "[$scriptName] mediaDir    : $mediaDir (default)"
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

switch ($version) {
	14 {
		$file = 'BuildTools_Full.exe'
		$uri = 'http://download.microsoft.com/download/E/E/D/EEDF18A8-4AED-4CE0-BEBE-70A83094FC5A/' + $file
	}
    default {
	    Write-Host "[$scriptName] version not supported, choices are $versionChoices"
    }
}

$installFile = $mediaDir + '\' + $file
Write-Host "[$scriptName] installFile : $installFile"

$logFile = $installDir = [Environment]::GetEnvironmentVariable('TEMP', 'user') + '\' + $file + '.log'
Write-Host "[$scriptName] logFile     : $logFile"

Write-Host
if ( Test-Path $installFile ) {
	Write-Host "[$scriptName] $installFile exists, download not required"
} else {

	$webclient = new-object system.net.webclient
	Write-Host "[$scriptName] $webclient.DownloadFile($uri, $installFile)"
	$webclient.DownloadFile($uri, $installFile)
}

try {
	$argList = @("/q")
	Write-Host "[$scriptName] Start-Process -FilePath $installFile -ArgumentList $argList -PassThru -Wait"
	$proc = Start-Process -FilePath $installFile -ArgumentList $argList -PassThru -Wait
} catch {
	Write-Host "[$scriptName] $installFile Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
