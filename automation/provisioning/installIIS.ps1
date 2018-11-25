Param (
	[string]$management,
	[string]$aspnet,
	[string]$proxy
)

$scriptName = 'installIIS.ps1'
cmd /c "exit 0"

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
		Write-Host "[$scriptName] Install failed, log file ($env:windir\logs\dism\dism.log) summary follows...`n"
		Compare-Object (get-content "$env:windir\logs\dism\dism.log") (Get-Content "$env:temp\dism.log")
		exit $LASTEXITCODE
	}
}

# Only from Windows Server 2016 and above
Write-Host "`n[$scriptName] ---------- start ----------"
if ( $management ) {
    Write-Host "[$scriptName] management : $management"
} else {
    Write-Host "[$scriptName] management : (not supplied)"
}
if ( $aspnet ) {
    Write-Host "[$scriptName] aspnet     : $aspnet"
} else {
    Write-Host "[$scriptName] aspnet     : (not supplied)"
}
if ( $proxy ) {
    Write-Host "[$scriptName] proxy      : $proxy"
    executeExpression "[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('$proxy')"
} else {
    Write-Host "[$scriptName] proxy      : (not supplied)"
}

# Create a baseline copy of the DISM log file, to use for logging informatio if there is an exception, note: this log is normally locked, so can't simply delete it
executeExpression "copy 'c:\windows\logs\dism\dism.log' $env:temp"

Write-Host "`n[$scriptName] Install default roles`n"
executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole"
executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer"
executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures"
executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpErrors"
executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpRedirect"
executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationDevelopment"

if ( $management ) {
	executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerManagementTools"
	$serverWithGUI = foreach ($property in Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Server\ServerLevels') { if ($property.PSobject.Properties.name -match 'Server-Gui-Shell') { $property } }
	if ( $serverWithGUI ) {	
		executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementConsole"
	} else {
		Write-Host "[$scriptName] Management tools selected, but operating system has no GUI so skipping IIS-ManagementConsole"
	}
}

if ($aspnet) {
	executeExpression "Enable-WindowsOptionalFeature -online -FeatureName NetFx4Extended-ASPNET45"
	executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-NetFxExtensibility45"
	executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45"
}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
$error.clear()
exit 0