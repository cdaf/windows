Param (
	[string]$enableTCP,
	[string]$restart,
	[string]$httpProxy,
	[string]$version,
	[string]$provider,
	[string]$dockerUser,
	[string]$compose
)

$scriptName = 'installDocker.ps1'
cmd /c "exit 0"

# Use executeReinstall to support reinstalling, use executeExpression to trap all errors ($LASTEXITCODE is global)
function execute ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Output $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    Write-Host
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
	    if ( $error ) { Write-Host "[$scriptName] Warning, message in `$error[0] = $error"; $error.clear() } # do not treat messages in error array as failure
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { $exitCode = $LASTEXITCODE; Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red; cmd /c "exit 0" }
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with `$LASTEXITCODE = $exitCode.`n"
				exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
				Start-Sleep $wait
				$wait = $wait + $wait
			}
		}
    }
}

# Fail on Message in Standard Error
function executeError ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Output $_.Exception|format-list -force; exit 2 }
    if ( $error ) { 
	    Write-Host "[$scriptName] Error during execution : $error[0]" -ForegroundColor Red
	    exit 3
	}
}

# Only from Windows Server 2016 and above
Write-Host "`n[$scriptName] ---------- start ----------"
if ($enableTCP) {
    Write-Host "[$scriptName]  enableTCP  : $enableTCP"
} else {
    Write-Host "[$scriptName]  enableTCP  : (not set)"
}
if ($restart) {
    Write-Host "[$scriptName]  restart    : $restart"
} else {
	$restart = 'yes'
    Write-Host "[$scriptName]  restart    : $restart (set to default)"
}
if ($httpProxy) {
    Write-Host "[$scriptName]  httpProxy  : $httpProxy"
	$proxyParameter = "-Proxy '$httpProxy'"
	[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy($httpProxy)
} else {
    Write-Host "[$scriptName]  httpProxy  : (not set)"
	$proxyURI = $([system.net.webrequest]::defaultwebproxy.Address).AbsoluteUri
	
	if ( $proxyURI ) {
		$proxyParameter = "-Proxy $proxyURI"
	    Write-Host "[$scriptName]  proxyURI   : $proxyURI"
	    [system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy($env:HTTP_PROXY)
	}
}

if ($version) {
    Write-Host "[$scriptName]  version    : $version"
	$versionParameter = "-RequiredVersion '$version'"
} else {
    Write-Host "[$scriptName]  version    : (not set, allow package manager to decide)"
}

if ($provider) {
    Write-Host "[$scriptName]  provider   : $provider (DockerMsftProviderInsider or DockerMsftProvider)"
} else {
	$provider = 'DockerMsftProvider'
    Write-Host "[$scriptName]  provider   : $provider (set to default, choices DockerMsftProviderInsider or DockerMsftProvider)"
}

if ($dockerUser) {
    Write-Host "[$scriptName]  dockerUser : $dockerUser"
} else {
    Write-Host "[$scriptName]  dockerUser : (not set)"
}

if (${compose}) {
    Write-Host "[$scriptName]  compose    : ${compose}`n"
} else {
	$compose = '1.27.4'
    Write-Host "[$scriptName]  compose    : ${compose} (default)`n"
}

$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
executeExpression '[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols'
executeExpression "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Verbose -Force $proxyParameter"

# Found these repositories unreliable so included retry logic
$galleryAvailable = Get-PSRepository -Name PSGallery*
if ($galleryAvailable) {
	Write-Host "[$scriptName] $((Get-PSRepository -Name PSGallery).Name) is already available"
} else {
	executeRetry "Register-PSRepository -Default"
}

# Avoid "You are installing the modules from an untrusted repository" message
executeRetry "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted"

executeRetry "Find-PackageProvider $proxyParameter *docker* | Format-Table Name, Version, Source"

executeRetry "Install-Module NuGet -Confirm:`$False $proxyParameter"

executeRetry "Install-Module -Name $provider -Repository PSGallery -Confirm:`$False -Verbose -Force $proxyParameter"

Write-Host "`n[$scriptName] Get-PackageSource"
$packageSource = $(Get-PackageSource)
$packageSource

$job = Start-Job {
	Get-PackageSource
} | Wait-Job
Receive-Job $job
Write-Host

executeError "Install-Package -Name 'Docker' -ProviderName $provider -Confirm:`$False -Verbose -Force $versionParameter"

executeExpression "sc.exe config docker start= delayed-auto"

if ($enableTCP) {
	if (!( Test-Path C:\ProgramData\docker\config\ )) {
		executeExpression "mkdir C:\ProgramData\docker\config\"
	}
	try {
		Add-Content C:\ProgramData\docker\config\daemon.json '{ "hosts": ["tcp://0.0.0.0:2375","npipe://"] }'
		Write-Host "`n[$scriptName] Enable TCP in config, will be applied after restart`n"
		executeExpression "Get-Content C:\ProgramData\docker\config\daemon.json" 
	} catch { Write-Output $_.Exception|format-list -force; exit 478 }
}

Write-Host "`n[$scriptName] Install docker-compose as per https://docs.docker.com/compose/install/"

executeExpression '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12'
executeExpression "Invoke-WebRequest 'https://github.com/docker/compose/releases/download/${compose}/docker-compose-Windows-x86_64.exe' -UseBasicParsing -OutFile `$Env:ProgramFiles\docker\docker-compose.exe"

if ($dockerUser) {
	Write-Host "`n[$scriptName] Add user to docker execution (without elevated admin session)"
	executeExpression "Install-Module -Name dockeraccesshelper -Confirm:`$False -Verbose -Force $proxyParameter"
	executeExpression 'Import-Module dockeraccesshelper'
	executeExpression "Add-AccountToDockerAccess '$dockerUser'"
}

if ($restart -eq 'yes') {
	executeExpression "shutdown /r /t 10"
} else {
	Write-Host "`n[$scriptName] Restart set to $restart, manual restart required"
}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
$error.clear()
exit 0