$scriptName = 'SDK.ps1'
$versionChoices = '4.5.2' 
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$version = $args[0]
if ($version) {
    Write-Host "[$scriptName] version     : $version"
} else {
	$version = '4.5.2'
    Write-Host "[$scriptName] version     : $version (default, choices $versionChoices)"
}

$mediaDir = $args[1]
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir    : $mediaDir"
} else {
	$mediaDir = 'C:\.provision'
    Write-Host "[$scriptName] mediaDir    : $mediaDir (default)"
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

switch ($version) {
	'4.5.2' {
		$file = 'NDP452-KB2901951-x86-x64-DevPack.exe'
		$uri = 'http://download.microsoft.com/download/4/3/B/43B61315-B2CE-4F5B-9E32-34CCA07B2F0E/' + $file
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

Write-Host
$argList = @('/q', '/norestart')
Write-Host "[$scriptName] Start-Process -FilePath $installFile -ArgumentList $argList -PassThru -Wait"
try {
	$proc = Start-Process -FilePath $installFile -ArgumentList $argList -PassThru -Wait
} catch {
	Write-Host "[$scriptName] $installFile Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
