$scriptName = 'VisualStudioShell.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$mediaDir      = $args[0]
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

$version      = $args[1]
if ($version) {
    Write-Host "[$scriptName] version : $version"
} else {
	$version = '2010'
    Write-Host "[$scriptName] version : $version (default)"
}

if ($version -eq '2010') { 
	$file = 'VSIsoShell.exe'
	$fullpath = $mediaDir + '\' + $file
	if ( Test-Path $fullpath ) {
		Write-Host "[$scriptName] $fullpath exists, download not required"
	} else {
	
		$webclient = new-object system.net.webclient
		$uri = 'https://download.microsoft.com/download/1/9/3/1939AD78-F8E8-4336-83F3-E2470F422C62/' + $file
		Write-Host "[$scriptName] $webclient.DownloadFile($uri, $fullpath)"
		$webclient.DownloadFile($uri, $fullpath)
	}
}

try {
	$argList = @("/q", "/norestart")
	Write-Host "[$scriptName] Start-Process -FilePath $fullpath -ArgumentList $argList -PassThru -Wait"
	$proc = Start-Process -FilePath $fullpath -ArgumentList $argList -PassThru -Wait
} catch {
	Write-Host "[$scriptName] .NET Install Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
