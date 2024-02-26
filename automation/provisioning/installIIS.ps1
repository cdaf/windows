Param (
	[string]$management,
	[string]$aspnet,
	[string]$proxy,
	[string]$iisadmin,
	[string]$iispasswd
)

$scriptName = 'installIIS.ps1'
$error.clear()
cmd /c "exit 0"

# Consolidated Error processing function
#  required : error message
#  optional : exit code, if not supplied only error message is written
function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Red
	} else {
		Write-Warning "`n[$scriptName]$message"
	}
	if ( $error ) {
		$i = 0
		foreach ( $item in $Error )
		{
			Write-Host "`$Error[$i] $item"
			$i++
		}
		$Error.clear()
	}
	if ( $exitcode ) {
		if ( $env:CDAF_ERROR_DIAG ) {
			Write-Host "`n[$scriptName] Invoke custom diag `$env:CDAF_ERROR_DIAG = $env:CDAF_ERROR_DIAG`n"
			Invoke-Expression $env:CDAF_ERROR_DIAG
		}
		Write-Host "`n[$scriptName] Exit with LASTEXITCODE = $exitcode`n" -ForegroundColor Red
		exit $exitcode
	}
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { ERRMSG "[TRAP] `$? = $?" 1211 }
	} catch {
		$message = $_.Exception.Message
		$_.Exception | format-list -force
		$_.Exception.StackTrace
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
			ERRMSG "[IIS][EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[IIS][EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			ERRMSG "[IIS][EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
		} else {
			if ( $error ) {
				ERRMSG "[IIS][WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[IIS][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				ERRMSG "[IIS][WARN] `$LASTEXITCODE not set, but standard error populated"
	    	}
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