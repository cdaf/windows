Write-Host
Write-Host "[provision.ps1] ---------- start ----------"
Write-Host

# The following are not compatible with Windows Server 2008
# cd ~
# Invoke-WebRequest
cd ~

# vagrant file share is dependant on provider
$provisioning = 'C:\vagrant\.provision'
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

	$shell_app=new-object -com shell.application
	$zip_file = $shell_app.namespace((Get-Location).Path + "\$file")
	$destination = $shell_app.namespace((Get-Location).Path)
	$destination.Copyhere($zip_file.items())
	Write-Host "7za.exe --> $provisioning"
	Copy-Item 7za.exe $provisioning
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
	Write-Host
	Write-Host "curl.exe --> $provisioning"
	Copy-Item curl.exe $provisioning
	Write-Host "ca-bundle.crt --> $provisioning"
	Copy-Item ca-bundle.crt $provisioning
}

# Runtime target added to path will only be available in a new session,
# therefore CDAF execution is performed in a subsequent invocation.
$runtime = 'C:\bin'

if (-not (Test-Path "$runtime")) {
	mkdir $runtime
}
Write-Host "[provision.ps1] Provisioning to $runtime (added to PATH)"
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$runtime", [EnvironmentVariableTarget]::Machine)
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

Write-Host
Write-Host "[provision.ps1] Add the localhost (127.0.0.2) as a trusted hosts for Remote Powershell (loopback)"
Set-WSManInstance -ResourceURI winrm/config/client -ValueSet @{TrustedHosts='127.0.0.2'}

Write-Host
Write-Host "[provision.ps1] ---------- stop -----------"
Write-Host