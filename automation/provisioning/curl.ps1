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

# vagrant file share is dependant on provider, for VirtualBox, pass as /.provision
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	# If not passed, default to the vagrant location
	$mediaDir = 'C:\.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

if (-not(Test-Path "$mediaDir")) {
	mkdir $mediaDir
}

# Where the 7zip installed software will reside
$7zipFQDN = 'www.7-zip.org'
$7zipDir = $args[1]
if ($7zipDir) {
    Write-Host "[$scriptName] 7zipDir  : $7zipDir"
} else {
	# If not passed, use the system root
	$7zipDir = $Env:SystemRoot
    Write-Host "[$scriptName] 7zipDir  : $7zipDir (default)"
}

# Where the curl installed software will reside
$curlFQDN = 'winampplugins.co.uk'
$curlDir = $args[2]
if ($curlDir) {
    Write-Host "[$scriptName] curlDir  : $curlDir"
} else {
	# If not passed, use the system root
	$curlDir = $Env:SystemRoot
    Write-Host "[$scriptName] curlDir  : $curlDir (default)"
}

if (-not(Test-Path "$mediaDir")) {
	mkdir $mediaDir
}

# Verify or download and install 7zip command line
Write-Host
$zipVersion = cmd /c 7za.exe i 2`>`&1
$zipVersion = $zipVersion | Select-String -Pattern '7-Zip'
if ( ! ( $zipVersion )) { 
	$webclient = new-object system.net.webclient
	$file = '7za920.zip'
	$fullpath = $mediaDir + '\' + $file
	if ( Test-Path $fullpath ) {
		Write-Host "[$scriptName] $fullpath exists, download not required"
	} else {
		$uri = "http://$7zipFQDN/a/" + $file
		executeExpression "`$webclient.DownloadFile(`'$uri`', `'$fullpath`')"
	}
	
	if ( ! (Test-Path "$7zipDir") ) {
		executeExpression "mkdir $7zipDir"
	}
	Add-Type -AssemblyName System.IO.Compression.FileSystem
	executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory(`'$fullpath`', `'$7zipDir`')"

	executeExpression "& 7za.exe i" 
}
Write-Host "[$scriptName] $zipVersion"

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
	$webclient = new-object system.net.webclient
	$uri = "http://$curlFQDN/curl/" + $file
	executeExpression "`$webclient.DownloadFile(`'$uri`', `'$fullpath`')"
}

executeExpression "& 7za.exe x $fullpath -o$curlDir -aoa"

$curlVersion = cmd /c curl.exe --version 2`>`&1
$curlVersion = $curlVersion | Select-String -Pattern 'libcurl'
if ( $curlVersion ) { 
	Write-Host "[$scriptName] $curlVersion"
} else {
	Write-Host "[$scriptName] curl.exe failed to install!"; exit 9
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host