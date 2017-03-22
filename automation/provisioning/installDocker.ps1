
# Only from Windows Server 2016 and above
$scriptName = 'installDocker.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"

# Requires KB3176936

try {
	Write-Host "[$scriptName] Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force"
	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
	
	Write-Host "[$scriptName] Set-PSRepository -Name PSGallery -InstallationPolicy Trusted"
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	
	Write-Host "[$scriptName] Install-Module -Name DockerMsftProvider -Repository PSGallery -Force -Confirm:`$False"
	Install-Module -Name DockerMsftProvider -Repository PSGallery -Force -Confirm:$False
	
	Write-Host "[$scriptName] Enable-WindowsOptionalFeature -Online -FeatureName Containers -All"
	Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
	
	Write-Host "[$scriptName] Install-Package -Name docker -ProviderName DockerMsftProvider -Force -Confirm:`$False"
	Install-Package -Name docker -ProviderName DockerMsftProvider -Force -Confirm:$False
	
} catch { echo $_.Exception|format-list -force; $exitCode = 5 }

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
