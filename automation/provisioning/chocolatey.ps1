$scriptName = 'chocolatey.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
Write-Host
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
$file = 'install.ps1'
$fullpath = $mediaDir + '\' + $file
if ( Test-Path $fullpath ) {
	Write-Host "[$scriptName] $fullpath exists, download not required"
} else {

	$webclient = new-object system.net.webclient
	$uri = 'https://chocolatey.org/' + $file
	Write-Host "[$scriptName] $webclient.DownloadFile($uri, $fullpath)"
	$webclient.DownloadFile($uri, $fullpath)
}

try {
	$argList = @("$fullpath")
	Write-Host "[$scriptName] Start-Process -FilePath 'powershell' -ArgumentList $argList -PassThru -Wait"
	$proc = Start-Process -FilePath 'powershell' -ArgumentList $argList -PassThru -Wait
} catch {
	Write-Host "[$scriptName] $file Install Exception : $_" -ForegroundColor Red
	exit 200
}

# Reload the path (without logging off and back on)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host