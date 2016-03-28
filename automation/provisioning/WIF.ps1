$scriptName = 'WIF.ps1'
Write-Host
Write-Host "[$scriptName] Windows Identity Framework"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$mediaDir = $args[0]

if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = 'c:\vagrant\.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

Write-Host
$file = 'Windows6.1-KB974405-x64.msu'
$uri = 'https://download.microsoft.com/download/D/7/2/D72FD747-69B6-40B7-875B-C2B40A6B2BDD/' + $file
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
	Write-Host "[$scriptName] Start-Process -FilePath `'wusa.exe`' -ArgumentList $argList -PassThru -wait -Verb RunAs"
	$proc = Start-Process -FilePath 'wusa.exe' -ArgumentList $argList -PassThru -wait -Verb RunAs
} catch {
	Write-Host "[$scriptName] PowerShell Install Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] List the WIF Installed Versions"
Write-Host "[$scriptName] Get-ChildItem `'HKLM:\SOFTWARE\Microsoft\Windows Identity Foundation\setup`'"
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows Identity Foundation\setup'
Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host