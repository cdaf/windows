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

# Only from Windows Server 2016 and above
$scriptName = 'installDocker.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName`""
}

# Requires KB3176936

try {
	Write-Host "[$scriptName] Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force"
	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
	
	Write-Host "[$scriptName] Set-PSRepository -Name PSGallery -InstallationPolicy Trusted"
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	
	Write-Host "[$scriptName] Install-Module -Name DockerMsftProvider -Repository PSGallery -Force -Confirm:`$False"
	Install-Module -Name DockerMsftProvider -Repository PSGallery -Force -Confirm:$False
	
	Write-Host "[$scriptName] Install-Package -Name docker -ProviderName DockerMsftProvider -Force -Confirm:`$False"
	Install-Package -Name docker -ProviderName DockerMsftProvider -Force -Confirm:$False
	
	executeExpression "shutdown /r /t 2"
	
} catch { echo $_.Exception|format-list -force; $exitCode = 5 }

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
