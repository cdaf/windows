$scriptName     = 'WIF.ps1'
$versionChoices = '4'
Write-Host
Write-Host "[$scriptName] --------------------------"
Write-Host "[$scriptName] Windows Identity Framework"
Write-Host "[$scriptName] --------------------------"
$version = $args[0]
if ($version) {
    Write-Host "[$scriptName] version  : $version"
} else {
	$version = '4'
    Write-Host "[$scriptName] version  : $version (default, choices $versionChoices)"
}

$mediaDir = $args[1]
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = 'C:\.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

Write-Host

switch ($version) {
	'4' {
		$file = 'Windows6.1-KB974405-x64.msu'
		$uri = 'https://download.microsoft.com/download/D/7/2/D72FD747-69B6-40B7-875B-C2B40A6B2BDD/' + $file
	}
    default {
	    Write-Host "[$scriptName] version not supported, choices are $versionChoices"
    }
}

Write-Host
$fullpath = $mediaDir + '\' + $file
if ( Test-Path $fullpath ) {
	Write-Host "[$scriptName] $fullpath exists, download not required"
} else {

	$webclient = new-object system.net.webclient
	Write-Host "[$scriptName] $webclient.DownloadFile($uri, $fullpath)"
	$webclient.DownloadFile($uri, $fullpath)
}

try {
	$argList = @("$fullpath", '/quiet', '/norestart')
	Write-Host "[$scriptName] Start-Process -FilePath `'wusa.exe`' -ArgumentList $argList -PassThru -Wait"
	$proc = Start-Process -FilePath 'wusa.exe' -ArgumentList $argList -PassThru -Wait
} catch {
	Write-Host "[$scriptName] PowerShell Install Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host