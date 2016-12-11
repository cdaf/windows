$scriptName = 'GetMedia.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$uri = $args[0]
if ($uri) {
    Write-Host "[$scriptName] uri      : $uri"
} else {
    Write-Host "[$scriptName] uri not supplied, exiting"
    exit 101
}

$mediaDir = $args[1]
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = '/.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

$filename = $uri.Substring($uri.LastIndexOf("/") + 1)
$fullpath = $mediaDir + '\' + $filename
if ( Test-Path $fullpath ) {
	Write-Host "[scriptName.ps1] $fullpath exists, download not required"
} else {

	$webclient = new-object system.net.webclient
	Write-Host "[$scriptName] $webclient.DownloadFile($uri, $fullpath)"
	$webclient.DownloadFile($uri, $fullpath)
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
