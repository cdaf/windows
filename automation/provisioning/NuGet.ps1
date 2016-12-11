$scriptName = 'NuGet.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$runtime = $args[0]
if ($runtime) {
    Write-Host "[$scriptName] runtime  : $runtime"
} else {
	$runtime = $env:windir
    Write-Host "[$scriptName] runtime  : $runtime (default)"
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

Write-Host
$file = 'nuget.exe'
$fullpath = $mediaDir + '\' + $file
if ( Test-Path $fullpath ) {
	Write-Host "[$scriptName] $fullpath exists, download not required"
} else {

	$webclient = new-object system.net.webclient
	$uri = 'https://nuget.org/' + $file
	Write-Host "[$scriptName] $webclient.DownloadFile($uri, $fullpath)"
	$webclient.DownloadFile($uri, $fullpath)
}

Write-Host "[$scriptName] Copy $file to $runtime"
Copy-Item $mediaDir/$file $runtime

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host