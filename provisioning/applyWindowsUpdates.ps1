# Only for Windows Server 2016 and above
$scriptName = 'applyWindowsUpdates.ps1'
Write-Host "`n[$scriptName] ---------- start ----------"
$autoRestart = $args[0]
if ($autoRestart) {
    Write-Host "[$scriptName] autoRestart   : $autoRestart"
} else {
	$autoRestart = 'yes'
    Write-Host "[$scriptName] autoRestart   : $autoRestart (default)"
}

try {
	Write-Host "[$scriptName] Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force"
	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
	
	Write-Host "[$scriptName] Set-PSRepository -Name PSGallery -InstallationPolicy Trusted"
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	
	Write-Host "[$scriptName] Install-Module -Name PSWindowsUpdate -Confirm:`$False"
	Install-Module -Name PSWindowsUpdate -Confirm:$False
	
	Write-Host "[$scriptName] Import-Module PSWindowsUpdate"
	Import-Module PSWindowsUpdate

	if ($autoRestart -eq 'yes') {
		Write-Host "[$scriptName] Get-WUInstall -Verbose -AcceptAll -AutoReboot:`$True -Confirm:`$False"
		Get-WUInstall -Verbose -AcceptAll -AutoReboot:$True -Confirm:$False
	} else {
		Write-Host "[$scriptName] Get-WUInstall -Verbose -AcceptAll -AutoReboot:`$False -Confirm:`$False"
		Get-WUInstall -Verbose -AcceptAll -AutoReboot:$False -Confirm:$False
	}
	
} catch { Write-Host $_.Exception|format-list -force; exit 5 }

Write-Host "`n[$scriptName] ---------- stop ----------"
