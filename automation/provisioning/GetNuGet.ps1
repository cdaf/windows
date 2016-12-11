function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
}

$scriptName = 'GetNuGet.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$mediaDir = $args[0]
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = '/.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

$uri = 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe'

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

executeExpression "Copy-Item $fullpath $env:SYSTEMROOT"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
