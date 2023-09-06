Param (
	[string]$management,
	[string]$aspnet,
	[string]$proxy,
	[string]$iisadmin,
	[string]$iispasswd
)

$scriptName = 'installIIS.ps1'
cmd /c "exit 0"

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1112 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] Install failed, log file ($env:windir\logs\dism\dism.log) summary follows...`n"
			Compare-Object (get-content "$env:windir\logs\dism\dism.log") (Get-Content "$env:temp\dism.log")
			$error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				$error
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName] `$error[] = $error"; exit 1113
		}
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

# Create a baseline copy of the DISM log file, to use for logging information if there is an exception, note: this log is normally locked, so can't simply delete it
if ( Test-Path 'c:\windows\logs\dism\dism.log' ) {
	executeExpression "copy 'c:\windows\logs\dism\dism.log' $env:temp"
} else {
	executeExpression "Add-Content $env:temp\dism.log ' '"
}

Write-Host "`n[$scriptName] Install default roles`n"
executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole"
executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer"
executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures"
executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpErrors"
executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpRedirect"
executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationDevelopment"

if ( $management ) {
	executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerManagementTools"

	$computer = "."
	$sOS =Get-WmiObject -class Win32_OperatingSystem -computername $computer
	foreach($sProperty in $sOS) {
		$caption = $sProperty.Caption
	}
	if (( $caption -match 'Windows 10' ) -or ( $caption -match 'Windows 11' )) {
		$osWithGUI = $caption
	} else {
		$osWithGUI = foreach ($property in Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Server\ServerLevels') { if ($property.PSobject.Properties.name -match 'Server-Gui-Shell') { $property } }
	}

	if ( $osWithGUI ) {	
		executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementConsole"
	} else {
		Write-Host "[$scriptName] Management tools selected, but operating system has no GUI so skipping IIS-ManagementConsole"
        if ($iisadmin) {
            #Add user for Remote IIS Manager Login
            $userExists = Get-LocalUser | Where-Object {$_.Name -eq $iisadmin}
            if ( ! $userExists )
            {
                executeExpression "net user $iisadmin $iispasswd /ADD"
                executeExpression "net localgroup administrators $iisadmin /add"
                Write-Host "[$scriptName] Install Web Management Service for remote management`n"
                executeExpression 'Install-WindowsFeature Web-Mgmt-Service'
                executeExpression 'New-ItemProperty -Path HKLM:\software\microsoft\WebManagement\Server -Name EnableRemoteManagement -Value 1 -Force;'
                executeExpression 'Set-Service -Name wmsvc -StartupType automatic;'
                executeExpression 'Restart-Service -Name wmsvc'
                executeExpression 'Restart-Service -Name w3svc'
            }
        }
	}
}

if ($aspnet) {
	executeExpression "Enable-WindowsOptionalFeature -online -FeatureName NetFx4Extended-ASPNET45"
	executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-NetFxExtensibility45"
	executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45 -All"
}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
$error.clear()
exit 0