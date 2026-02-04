Param (
	[string]$port
)

# Consolidated Error processing function
function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Red
	} else {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Yellow
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
	if ( $env:CDAF_ERROR_DIAG ) {
		Write-Host "`n[$scriptName] Invoke custom diag `$env:CDAF_ERROR_DIAG = $env:CDAF_ERROR_DIAG`n"
		Invoke-Expression $env:CDAF_ERROR_DIAG
	}
	if ( $exitcode ) {
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
			ERRMSG "[EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			ERRMSG "[EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
		} else {
			if ( $error ) {
				ERRMSG "[WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				ERRMSG "[WARN] `$LASTEXITCODE not set, but standard error populated"
	    	}
		}
	}
}

$scriptName = 'bootstrap-arr.ps1'
cmd /c "exit 0" # ensure LASTEXITCODE is 0

Write-Host "`n[$scriptName] ---------- start ----------"
if ($port) {
    Write-Host "[$scriptName] port   : $port"
} else {
    Write-Host "[$scriptName] port   : (not supplied, reverse proxy will not be configured)"
}

Write-Host "[$scriptName] pwd    = $(pwd)"
Write-Host "[$scriptName] whoami = $(whoami)`N"

executeExpression "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls11,Tls12'"
. { iwr -useb https://raw.githubusercontent.com/cdaf/windows/master/provisioning.ps1 } | iex

executeExpression "DISM /Online /Enable-Feature /all /FeatureName:IIS-WebServerRole /FeatureName:IIS-WebServer"

if ( Test-Path 'C:\.provision' ) {
	$mediaPath = 'C:\.provision'
} else {
	$mediaPath = "$env:TEMP"
}	 

Write-Host "[$scriptName] Install Application Request Routing (ARR)"
executeExpression "Stop-Service W3SVC"
executeExpression ".\provisioning\GetMedia.ps1 https://download.microsoft.com/download/E/9/8/E9849D6A-020E-47E4-9FD0-A023E99B54EB/requestRouter_amd64.msi"
executeExpression ".\provisioning\installMSI.ps1 $mediaPath\requestRouter_amd64.msi"
executeExpression ".\provisioning\GetMedia.ps1 https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi"
executeExpression ".\provisioning\installMSI.ps1 $mediaPath\rewrite_amd64_en-US.msi"
executeExpression "Start-Service W3SVC"

if ($port) {
	
	Write-Host "[$scriptName] Enable and Configure Reverse Proxy"
	executeExpression "Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Name 'enabled' -Filter 'system.webServer/proxy' -Value 'True'"

	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "<?xml version=`"1.0`" encoding=`"UTF-8`"?>"'
	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "<configuration>"'
	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "    <system.webServer>"'
	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "        <rewrite>"'
	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "            <rules>"'
	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "                <clear />"'
	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "                <rule name=`"ReverseProxyInboundRule1`" stopProcessing=`"true`">"'
	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "                    <match url=`"(.*)`" />"'
	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "                    <conditions logicalGrouping=`"MatchAll`" trackAllCaptures=`"false`" />"'
	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "                    <action type=`"Rewrite`" url=`"http://localhost:$port/{R:1}`" />"'
	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "                </rule>"'
	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "            </rules>"'
	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "        </rewrite>"'
	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "    </system.webServer>"'
	executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "</configuration>"'
}

if ( Test-Path "C:\inetpub\wwwroot\web.config" ) {
	executeExpression 'Get-Content C:\inetpub\wwwroot\web.config'
} else {
	Write-Host "C:\inetpub\wwwroot\web.config does not exist, ARR not configured."
}

Write-Host "`n[$scriptName] ---------- stop ----------"
