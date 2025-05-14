# Only from Windows Server 2016 and above
$scriptName = 'trustPowerShellGallery.ps1'

# Use executeReinstall to support reinstalling, use executeExpression to trap all errors ($LASTEXITCODE is global)
function execute ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
}

function executeExpression ($expression) {
	execute $expression
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "ERROR! Exiting with `$LASTEXITCODE = $LASTEXITCODE"; exit $LASTEXITCODE }
}

function executeReinstall ($expression) {
	execute $expression
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -eq 1060 ) {
	    	Write-Host "Product reinstalled, returning `$LASTEXITCODE = 0"; cmd /c "exit 0"
    	} else {
	    	if ( $LASTEXITCODE -ne 0 ) {
		    	Write-Host "ERROR! Exiting with `$LASTEXITCODE = $LASTEXITCODE"; exit $LASTEXITCODE
	    	}
    	}
    }
}

# Retry logic for connection issues, i.e. "Cannot retrieve the dynamic parameters for the cmdlet. PowerShell Gallery is currently unavailable.  Please try again later."
function executeRetry ($expression) {
	$exitCode = 1
	$wait = 10
	$retryMax = 5
	$retryCount = 0
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "[$retryCount] $expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
		} catch { Write-Host "[$scriptName] $_"; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] Warning, message in `$error[0] = $error"; $error.clear() } # do not treat messages in error array as failure
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { $exitCode = $LASTEXITCODE; Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red; cmd /c "exit 0" }
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with `$LASTEXITCODE = $exitCode.`n"
				exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
				sleep $wait
			}
		}
    }
}

Write-Host "`n[$scriptName] ---------- start ----------`n"
if ($env:http_proxy) {
    Write-Host "[$scriptName] `$env:http_proxy : $env:http_proxy`n"
    $env:https_proxy = $env:http_proxy
    executeExpression "[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('$env:http_proxy')"

    # http://raghablog.blogspot.com/2014/12/powershell-scripts-for-changing-proxy.html
    # https://gallery.technet.microsoft.com/scriptcenter/PowerShell-function-Get-cba2abf5
	$protocol,$prefix,$port = $env:http_proxy.split(':')
	$address = $prefix.Replace('/', '')
	$regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
	executeExpression "Set-ItemProperty -path '$regKey' ProxyEnable -value 1"
	executeExpression "Set-ItemProperty -path '$regKey' ProxyServer -value '${address}:${port}'"
	executeExpression "Set-ItemProperty -path '$regKey' ProxyOverride -value '<local>;target;10.*'"	
	executeExpression "Get-ItemProperty '$regKey'"

    # https://parsiya.net/blog/2017-10-08-thick-client-proxying---part-8---notes-on-proxying-windows-services/
	Write-Host "`n[$scriptName] List current settings before changing`n"
	executeExpression "netsh winhttp show proxy"
	executeExpression "netsh winhttp set proxy proxy-server=`"http=${address}:${port};https=${address}:${port}`" bypass-list=`"target;localhost`""
	# executeExpression "netsh winhttp import proxy source=ie"

    # https://www.techazine.com/2015/08/11/configuring-system-wide-proxy-for-net-web-applications-including-sharepoint/
    [xml]$xmldata = get-content 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\Config\web.config'
	Write-Host "`n[$scriptName] .NET Framework web.config usesystemdefault : $($xmldata.configuration.'system.net'.defaultProxy.proxy.usesystemdefault)"

    [xml]$xmldata = get-content 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config\web.config'
	Write-Host "[$scriptName] .NET Framework64 web.config usesystemdefault : $($xmldata.configuration.'system.net'.defaultProxy.proxy.usesystemdefault)"

} else {
    Write-Host "[$scriptName] `$env:http_proxy : (not set)`n"
}

executeExpression "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls11,Tls12'"

# Found these repositories unreliable so included retry logic
$galleryAvailable = Get-PSRepository -Name PSGallery*
if ($galleryAvailable) {
	Write-Host "[$scriptName] $((Get-PSRepository -Name PSGallery).Name) is already available"
} else {
	executeRetry "Register-PSRepository -Default"
}

executeReinstall "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force"

executeRetry "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted"

executeRetry "Install-Module NuGet -Confirm:`$False"

Write-Host "`n[$scriptName] ---------- stop ----------`n"
