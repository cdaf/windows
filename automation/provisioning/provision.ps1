function Unzip
{
	Add-Type -AssemblyName System.IO.Compression.FileSystem
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

Write-Host
Write-Host "[provision.ps1] ---------- start ----------"
Write-Host
$provisioning = $args[0]
$runtime      = $args[1]

# vagrant file share is dependant on provider, for VirtualBox, pass as C:\vagrant\.provision
if ($provisioning) {
    Write-Host "[$scriptName] provisioning : $provisioning"
} else {
	$provisioning = $(pwd)
    Write-Host "[$scriptName] provisioning : $provisioning (default)"
}

# If the runtime is passed, this will be appended to the path
if ($runtime) {
    Write-Host "[$scriptName] runtime : $runtime"
} else {
	$provisioning = '.'
    Write-Host "[$scriptName] runtime not passed, no changes to path will be made"
}

if (-not(Test-Path "$provisioning")) {
	mkdir $provisioning
}

if (Test-Path "$provisioning\7za.exe") {
	Write-Host "$provisioning\7za.exe exists, download not required"
} else {
	$file='7za920.zip'
	$root = 'http://www.7-zip.org/a/'
	$uri = $root + $file
	Write-Host "Invoke-WebRequest -uri $uri -OutFile $file"
	Invoke-WebRequest -uri $uri -OutFile $file
	if(!$?) { Write-Host "Invoke-WebRequest -uri $uri -OutFile $file FAILED!"; exit 102 }

	Write-Host "Unzip $file $provisioning"
	Unzip $file $provisioning
}

if (Test-Path "$provisioning\curl.exe") {
	Write-Host "$provisioning\curl.exe exists, download not required"
} else {
	$file='curl_7_47_1_openssl_nghttp2_x64.7z'
	$root = 'http://winampplugins.co.uk/curl/'
	$uri = $root + $file
	Write-Host "Invoke-WebRequest -uri $uri -OutFile $file"
	Invoke-WebRequest -uri $uri -OutFile $file
	if(!$?) { Write-Host "Invoke-WebRequest -uri $uri -OutFile $file FAILED!"; exit 102 }
	& $provisioning\7za.exe x $file
}

# Runtime target added to path will only be available in a new session,
# therefore CDAF execution is performed in a subsequent invocation.
if ($runtime) {
	
	if (-not (Test-Path "$runtime")) {
		mkdir $runtime
	}
	Write-Host
	$array = @(	
		"ca-bundle.crt",
		"curl.exe",
		"7za.exe"
	)
	foreach ($element in $array) {
		Write-Host "$provisioning\$element --> $runtime\$element"
		Copy-Item "$provisioning\$element" "$runtime\$element"
	}
}
	
Write-Host
Write-Host "[provision.ps1] Add the localhost (127.0.0.2) as a trusted hosts for Remote Powershell (loopback)"
Set-WSManInstance -ResourceURI winrm/config/client -ValueSet @{TrustedHosts='127.0.0.2'}

Write-Host
Write-Host "[provision.ps1] ---------- stop -----------"
Write-Host