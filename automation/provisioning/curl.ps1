# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
}

$scriptName = 'curl.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
Write-Host
$mediaDir = $args[0]

# vagrant file share is dependant on provider, for VirtualBox, pass as /vagrant/.provision
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir  : $mediaDir"
} else {
	# If not passed, default to the vagrant location
	$mediaDir = 'C:\vagrant\.provision'
    Write-Host "[$scriptName] mediaDir  : $mediaDir (default)"
}

if (-not(Test-Path "$mediaDir")) {
	mkdir $mediaDir
}

# Where the installed software will reside
$targetDir = $args[1]
if ($targetDir) {
    Write-Host "[$scriptName] targetDir : $targetDir"
} else {
	# If not passed, use the system root
	$targetDir = $Env:SystemRoot
    Write-Host "[$scriptName] targetDir : $targetDir (default)"
}

if (-not(Test-Path "$mediaDir")) {
	mkdir $mediaDir
}

# Verify or download and install 7zip command line
Write-Host
$zipVersion = cmd /c 7z i 2`>`&1
$zipVersion = $zipVersion | Select-String -Pattern '7-Zip'
if ( $zipVersion ) { 
	Write-Host "[$scriptName] $zipVersion"
} else {
	$webclient = new-object system.net.webclient
	$file = '7z1514-x64.exe'
	$fullpath = $mediaDir + '\' + $file
	if ( Test-Path $fullpath ) {
		Write-Host "[$scriptName] $fullpath exists, download not required"
	} else {
	
		$uri = 'http://www.7-zip.org/a/' + $file
		executeExpression "`$webclient.DownloadFile(`'$uri`', `'$fullpath`')"
	}
	
	if ( ! (Test-Path "$targetDir\7z\7z.exe") ) {
		Write-Host "Install $file to $targetDir"
		& $fullpath /S /D=$targetDir\7z
	}
	$zipVersion = cmd /c 7z i 2`>`&1
	$zipVersion = $zipVersion | Select-String -Pattern '7-Zip'
}

# TODO: parse this page and determine the current version
# Invoke-WebRequest -UseBasicParsing http://winampplugins.co.uk/curl

# If currently installed, list the version, then replace.
Write-Host
$curlVersion = cmd /c curl.exe --version 2`>`&1
$curlVersion = $curlVersion | Select-String -Pattern 'libcurl'
if ( $curlVersion ) { 
	Write-Host "[$scriptName] $curlVersion"
} else {
	Write-Host "[$scriptName] curl.exe not installed"
}

$file = 'curl_7_50_3_openssl_nghttp2_x64.7z'
$fullpath = $mediaDir + '\' + $file
if ( Test-Path $fullpath ) {
	Write-Host "[$scriptName] $fullpath exists, download not required"
} else {
	$uri = 'http://winampplugins.co.uk/curl/' + $file
	executeExpression "`$webclient.DownloadFile(`'$uri`', `'$fullpath`')"
}

executeExpression "& 7z x $fullpath -o$targetDir -aoa"

$curlVersion = cmd /c curl.exe --version 2`>`&1
$curlVersion = $curlVersion | Select-String -Pattern 'libcurl'
if ( $curlVersion ) { 
	Write-Host "[$scriptName] $curlVersion"
} else {
	Write-Host "[$scriptName] curl.exe not installed"
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host