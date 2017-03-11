# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$wait = 10
	$retryMax = 10
	$retryCount = 0
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "[$scriptName][$retryCount] $expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
		} catch { echo $_.Exception|format-list -force; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; $exitCode = 3 }
	    if ($exitCode -gt 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with code $exitCode"; exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
				sleep $wait
			}
		}
    }
}

# Only from Windows Server 2016 and above
$scriptName = 'installDocker.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"

# From https://docs.microsoft.com/en-us/virtualization/windowscontainers/quick-start/quick-start-windows-server

executeExpression  "Install-Module -Name DockerMsftProvider -Repository PSGallery -Force"
executeExpression  "Install-Package -Name docker -ProviderName DockerMsftProvider -Force"

# From https://marckean.com/2016/06/01/use-powershell-to-install-windows-updates/

executeExpression  "Install-Module PSWindowsUpdate"
executeExpression  "Get-Command –module PSWindowsUpdate"

executeExpression  "Add-WUServiceManager -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d"
executeExpression  "Get-WUInstall –MicrosoftUpdate –AcceptAll –AutoReboot"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
