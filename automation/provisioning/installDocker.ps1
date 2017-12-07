Param (
	[string]$enableTCP,
	[string]$restart
)

# Use executeReinstall to support reinstalling, use executeExpression to trap all errors ($LASTEXITCODE is global)
function execute ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
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
		Write-Host "[$scriptName][$retryCount] $expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
		} catch { Write-Host "[$scriptName] $_"; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] Warning, message in `$error[0] = $error"; $error.clear() } # do not treat messages in error array as failure
	    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode "; $exitCode = $lastExitCode }
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with `$LASTEXITCODE = $exitCode.`n"
				exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
				sleep $wait
				$wait = $wait + $wait
			}
		}
    }
}

# Only from Windows Server 2016 and above
$scriptName = 'installDocker.ps1'
Write-Host "`n[$scriptName] Requires KB3176936"
Write-Host "`n[$scriptName] ---------- start ----------"
if ($enableTCP) {
    Write-Host "[$scriptName]  enableTCP : $enableTCP"
} else {
    Write-Host "[$scriptName]  enableTCP : (not set)"
}
if ($restart) {
    Write-Host "[$scriptName]  restart   : $restart"
} else {
	$restart = 'yes'
    Write-Host "[$scriptName]  restart   : $restart (set to default)"
}

executeReinstall "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Verbose -Force"

executeRetry "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted"

executeRetry "Find-PackageProvider *docker* | Format-Table Name, Version, Source"

executeRetry "Install-Module NuGet -Confirm:`$False"

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
		executeExpression "Get-Content C:\ProgramData\docker\config\daemon.json" 
	} catch { echo $_.Exception|format-list -force; exit 478 }
}

executeExpression "Invoke-WebRequest 'https://github.com/docker/compose/releases/download/1.17.0/docker-compose-Windows-x86_64.exe' -UseBasicParsing -OutFile `$Env:ProgramFiles\docker\docker-compose.exe"

if ($restart -eq 'yes') {
	executeExpression "shutdown /r /t 10"
} else {
	Write-Host "`n[$scriptName] Restart set to $restart, manual restart required"
}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
$error.clear()
exit 0