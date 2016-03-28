Write-Host
Write-Host "[get3rd.ps1] ---------- start ----------"
Write-Host
$mediaDir = $args[0]

# vagrant file share is dependant on provider, for VirtualBox, pass as /vagrant/.provision
if ($mediaDir) {
    Write-Host "[get3rd.ps1] mediaDir : $mediaDir"
} else {
	# If not passed, default to the current users home
	$mediaDir = $env:USERPROFILE
    Write-Host "[get3rd.ps1] mediaDir : $mediaDir (default)"
}

if (-not(Test-Path "$mediaDir")) {
	mkdir $mediaDir
}

# Where the installed software will reside
$targetDir = $args[1]
if ($targetDir) {
    Write-Host "[get3rd.ps1] targetDir : $targetDir"
} else {
	# If not passed, default to the system TEMP directory
	$targetDir = [Environment]::GetEnvironmentVariable('TEMP', 'Machine')
    Write-Host "[get3rd.ps1] targetDir : $targetDir (default)"
}

if (-not(Test-Path "$mediaDir")) {
	mkdir $mediaDir
}

$webclient = new-object system.net.webclient
$file = '7z1514-x64.exe'
$fullpath = $mediaDir + '\' + $file
if ( Test-Path $fullpath ) {
	Write-Host "[get3rd.ps1] $fullpath exists, download not required"
} else {

	$uri = 'http://www.7-zip.org/a/' + $file
	Write-Host "[get3rd.ps1] $webclient.DownloadFile($uri, $fullpath)"
	$webclient.DownloadFile($uri, $fullpath)
}

if ( ! (Test-Path "$targetDir\7z\7z.exe") ) {
	Write-Host "Install $file to $mediaDir"
	& $fullpath /S /D=$targetDir\7z
}

$file = 'curl_7_48_0_openssl_nghttp2_x64.7z'
$fullpath = $mediaDir + '\' + $file
if ( Test-Path $fullpath ) {
	Write-Host "[get3rd.ps1] $fullpath exists, download not required"
} else {
	$uri = 'http://winampplugins.co.uk/download.php?file=curl/' + $file
	Write-Host "[get3rd.ps1] $webclient.DownloadFile($uri, $file)"
	$webclient.DownloadFile($uri, $file)

	Write-Host "[get3rd.ps1] & $targetDir\7z\7z.exe x $fullpath"
	& $targetDir\7z\7z.exe x $fullpath
}

Write-Host
Write-Host "[get3rd.ps1] ---------- stop -----------"
Write-Host