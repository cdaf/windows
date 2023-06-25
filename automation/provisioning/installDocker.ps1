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
			ERRMSG "[EXEC][EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[EXEC][EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			ERRMSG "[EXEC][EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
		} else {
			if ( $error ) {
				ERRMSG "[EXEC][WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[EXEC][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				ERRMSG "[EXEC][WARN] `$LASTEXITCODE not set, but standard error populated"
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

if ( $compose ) {
    Write-Host "[$scriptName]  compose    : ${compose}`n"
} else {
	$compose = '2.19.0'
    Write-Host "[$scriptName]  compose    : ${compose} (default)`n"
}

Write-Host "`n[$scriptName] Install docker-compose as per https://docs.docker.com/compose/install/"
executeExpression '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12'

executeExpression "Invoke-WebRequest `"https://github.com/docker/compose/releases/download/v${compose}/docker-compose-Windows-x86_64.exe`" -UseBasicParsing -OutFile `"`$env:windir\docker-compose.exe`""

if ( $dockerUser ) {
	Write-Host "`n[$scriptName] Add user to docker execution (without elevated admin session)"
	executeExpression "Install-Module -Name dockeraccesshelper -Confirm:`$False -Verbose -Force $proxyParameter"
	executeExpression 'Import-Module dockeraccesshelper'
	executeExpression "Add-AccountToDockerAccess '$dockerUser'"
}

if ( $ecosystem -eq 'containerd' ) {

	executeExpression "Invoke-WebRequest -UseBasicParsing `"https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-ContainerdRuntime/install-containerd-runtime.ps1`" -o install-containerd-runtime.ps1"
	REPLAC ".\install-containerd-runtime.ps1" "Restart-Computer -Force" "Write-Host 'Restart-Computer -Force'"
	REPLAC ".\install-containerd-runtime.ps1" "Restart-Computer" "Write-Host 'Restart-Computer'"
	REPLAC ".\install-containerd-runtime.ps1" "Set-ItemProperty -Path" "swap1`nSet-ItemProperty -Path"
	REPLAC ".\install-containerd-runtime.ps1" "swap1" 'cp "${NerdCTLPath}\nerdctl.exe" "${NerdCTLPath}\docker.exe"'
	executeExpression ".\install-containerd-runtime.ps1"
	
} else {

	executeExpression "Invoke-WebRequest -UseBasicParsing `"https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1`" -o install-docker-ce.ps1"
	REPLAC ".\install-docker-ce.ps1" "Restart-Computer -Force" "Write-Host 'Restart-Computer -Force'"
	REPLAC ".\install-docker-ce.ps1" "Restart-Computer" "Write-Host 'Restart-Computer'"
	executeExpression ".\install-docker-ce.ps1"

}

if ($restart -eq 'yes') {
	executeExpression "shutdown /r /t 10"
} else {
	Write-Host "`n[$scriptName] Restart set to $restart, manual restart required"
}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
$error.clear()
exit 0