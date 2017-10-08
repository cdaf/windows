Param (
	[string]$enableTCP
)
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

function executeRetry ($expression) {
	$exitCode = 1
	$lastExitCode = 0
	$wait = 10
	$retryMax = 3
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
	    if ( $lastExitCode -ne 0 ) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode "; $exitCode = $lastExitCode }
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with `$LASTEXITCODE = $exitCode. Log file ($env:windir\logs\dism\dism.log) summary follows...`n"
				Compare-Object (get-content "$env:windir\logs\dism\dism.log") (Get-Content "$env:temp\dism.log")
				exit $exitCode
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
Write-Host "`n[$scriptName] Requires KB3176936"
Write-Host "`n[$scriptName] ---------- start ----------`n"
if ($enableTCP) {
    Write-Host "[$scriptName] enableTCP   : $enableTCP"
} else {
    Write-Host "[$scriptName] enableTCP   : (not set)"
}

executeExpression "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Verbose -Force"

executeExpression "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; `$error.clear()"

executeExpression "Find-PackageProvider *docker* | Format-Table Name, Version, Source"

executeExpression "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force"
executeExpression "Install-Module NuGet -Confirm:`$False"

Write-Host "`n[$scriptName] Found these repositories unreliable`n"
executeRetry "Install-Module -Name DockerMsftProviderInsider -Repository PSGallery -Confirm:`$False -Verbose -Force"
executeRetry "Install-Package -Name docker -ProviderName DockerMsftProviderInsider -Confirm:`$False -Verbose -Force"

executeExpression "sc.exe config docker start= delayed-auto"

if ($enableTCP) {
	if (!( Test-Path C:\ProgramData\docker\config\ )) {
		executeExpression "mkdir C:\ProgramData\docker\config\"
	}
	try {
		Add-Content C:\ProgramData\docker\config\daemon.json '{ "hosts": ["tcp://0.0.0.0:2375","npipe://"] }'
		Write-Host "`n[$scriptName] Enable TCP in config, will be applied after restart`n"
		Get-Content C:\ProgramData\docker\config\daemon.json 
	} catch { echo $_.Exception|format-list -force; $exitCode = 478 }
}

executeExpression "shutdown /r /t 10"

Write-Host "`n[$scriptName] ---------- stop ----------`n"
