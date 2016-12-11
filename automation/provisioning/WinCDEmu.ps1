$scriptName = 'WinCDEmu.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$wincdemuarg = $args[0]
if ($wincdemuarg) {
    Write-Host "[$scriptName] wincdemuarg : $wincdemuarg (install or ISO image file)"
} else {
	$wincdemuarg = '/install'
    Write-Host "[$scriptName] wincdemuarg : $wincdemuarg (default)"
}

$mediaDir = $args[1]
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir    : $mediaDir"
} else {
	$mediaDir = '/.provision'
    Write-Host "[$scriptName] mediaDir    : $mediaDir (default)"
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

Write-Host
$file = 'PortableWinCDEmu-4.0.exe'
$fullpath = $mediaDir + '\' + $file
if ( Test-Path $fullpath ) {
	Write-Host "[$scriptName] $fullpath exists, download not required"
} else {

	$webclient = new-object system.net.webclient
	$uri = 'http://sysprogs.com/files/WinCDEmu/' + $file
	Write-Host "[$scriptName] $webclient.DownloadFile($uri, $fullpath)"
	$webclient.DownloadFile($uri, $fullpath)
}

try {
	$argList = @("$wincdemuarg", "/wait")
	Write-Host "[$scriptName] Start-Process -FilePath $fullpath -ArgumentList $argList -PassThru -Wait"
	$proc = Start-Process -FilePath $fullpath -ArgumentList $argList -PassThru -Wait
} catch {
	Write-Host "[$scriptName] $file Install Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host