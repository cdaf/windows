Param (
	[string]$ecosystem,
	[string]$restart,
	[string]$compose
)

$scriptName = 'installDocker.ps1'
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
				Start-Sleep $wait
				$wait = $wait + $wait
			}
		}
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
			ERRMSG "[DOCKER][EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[DOCKER][EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			ERRMSG "[DOCKER][EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
		} else {
			if ( $error ) {
				ERRMSG "[DOCKER][WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[DOCKER][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				ERRMSG "[DOCKER][WARN] `$LASTEXITCODE not set, but standard error populated"
	    	}
		}
	}
}

# Replace in file
#  required : file name relative to current workspace
#  required : the token to be replaced or an array of name/value pairs
#  optional : the replacement value (not passed if name is array)
function REPLAC ( $fileName, $tokenOrArray, $value ) {
	if (!( Test-Path $fileName )) {
		ERRMSG "REPLAC_FILE_NOT_FOUND $fileName" 1214
	}
	try {
		(Get-Content $fileName | ForEach-Object { $_ -replace [regex]::Escape($tokenOrArray), "$value" } ) | Set-Content $fileName
	    if(!$?) { taskException "REPLAC_EXIT" }
	} catch {
		Write-Host "`n[$scriptName] Exception occured in REPLAC( $fileName, $tokenOrArray, $value )`n" -ForegroundColor Red
		taskException "REPLAC_TRAP" $_
	}
}

# Only from Windows Server 2016 and above
# May 23rd 2023, DockerMsftProvider deprecated https://github.com/OneGet/MicrosoftDockerProvider
# 2.6.3 use Microsoft scripts for Docker Community Edition (CE) and Containerd
# https://learn.microsoft.com/en-us/virtualization/windowscontainers/quick-start/set-up-environment?tabs=containerd#windows-server-1
Write-Host "`n[$scriptName] ---------- start ----------"
if ( $ecosystem ) {
    Write-Host "[$scriptName]  ecosystem  : $ecosystem (options are ce or containerd)"
} else {
	$ecosystem = 'ce'
    Write-Host "[$scriptName]  ecosystem  : $ecosystem (default, options are ce or containerd)"
}

if ( $restart ) {
    Write-Host "[$scriptName]  restart    : $restart"
} else {
	$restart = 'yes'
    Write-Host "[$scriptName]  restart    : $restart (set to default)"
}

if ( $compose_version ) {
    Write-Host "[$scriptName]  compose    : ${compose_version}"
} else {
	$compose_version = (curl.exe -L --silent https://github.com/docker/compose/releases/latest | findstr '<title>Release').Split()[3]
    Write-Host "[$scriptName]  compose    : ${compose_version} (default)"
}

$CurrentBuild = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'CurrentBuild').CurrentBuild
write-host "[$scriptName]  Win build  : $CurrentBuild"

if ( $dockerUser ) {
	Write-Host "`n[$scriptName] Add user to docker execution (without elevated admin session)"
	executeExpression "Install-Module -Name dockeraccesshelper -Confirm:`$False -Verbose -Force $proxyParameter"
	executeExpression 'Import-Module dockeraccesshelper'
	executeExpression "Add-AccountToDockerAccess '$dockerUser'"
}

# Use old method for Windows Server 2016, else service will not start
# fatal: failed to start daemon: this version of Windows does not support the docker daemon (Windows build 17763 or higher is required)
if ( $CurrentBuild -lt 17763 ) {
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
	
	executeRetry "Get-PackageSource | Format-Table Name, ProviderName, IsTrusted"
	
	executeRetry "Install-Package -Name 'Docker' -ProviderName $provider -Confirm:`$False -Verbose -Force $versionParameter"
	
	executeExpression "sc.exe config docker start= delayed-auto"
	
	if ( $env:ENABLE_TCP ) {
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
	executeExpression "Invoke-WebRequest 'https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-Windows-x86_64.exe' -UseBasicParsing -OutFile `$Env:ProgramFiles\docker\docker-compose.exe"

} else {

	if ( $ecosystem -eq 'containerd' ) {
	
		executeExpression "curl.exe -L --silent https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-ContainerdRuntime/install-containerd-runtime.ps1 -o install-containerd-runtime.ps1"
		REPLAC ".\install-containerd-runtime.ps1" "Restart-Computer -Force" "Write-Host 'Restart-Computer -Force'"
		REPLAC ".\install-containerd-runtime.ps1" "Restart-Computer" "Write-Host 'Restart-Computer'"
		REPLAC ".\install-containerd-runtime.ps1" "Set-ItemProperty -Path" "swap1`nSet-ItemProperty -Path"
		REPLAC ".\install-containerd-runtime.ps1" "swap1" 'cp "${NerdCTLPath}\nerdctl.exe" "${NerdCTLPath}\docker.exe"'
		executeExpression ".\install-containerd-runtime.ps1 -NerdCTLVersion '1.1.0'"
	
	} else {
	
		executeExpression "curl.exe -L --silent https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1 -o install-docker-ce.ps1"
		REPLAC ".\install-docker-ce.ps1" "Restart-Computer -Force" "Write-Host 'Restart-Computer -Force'"
		REPLAC ".\install-docker-ce.ps1" "Restart-Computer" "Write-Host 'Restart-Computer'"
		executeExpression ".\install-docker-ce.ps1"
	
	}
	
	Write-Host "`n[$scriptName] Install docker-compose as per https://docs.docker.com/compose/install/"
	executeExpression "curl.exe -L --silent https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-Windows-x86_64.exe -o $env:windir\docker-compose.exe"
}

if ($restart -eq 'yes') {
	executeExpression "shutdown /r /t 10"
} else {
	Write-Host "`n[$scriptName] Restart set to $restart, manual restart required"
}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
$error.clear()
exit 0