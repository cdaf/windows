Param (
	[String]$interface
)
$scriptName = 'installAzureRM.ps1'

# Retry logic for connection issues, i.e. "Cannot retrieve the dynamic parameters for the cmdlet. PowerShell Gallery is currently unavailable.  Please try again later."
# Includes warning for "Cannot find a variable with the name 'PackageManagementProvider'. Cannot find a variable with the name 'SourceLocation'."
function executeRetry ($expression) {
	$exitCode = 1
	$wait = 10
	$retryMax = 5
	$retryCount = 0
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "$expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?" -ForegroundColor Red; $exitCode = 1 }
		} catch { Write-Host "[$scriptName] $_" -ForegroundColor Red; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] Warning, message in `$error[0] = $error" -ForegroundColor Yellow; $error.clear() } # do not treat messages in error array as failure
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

cmd /c "exit 0"
# Use the CDAF provisioning helpers
Write-Host "`n[$scriptName] ---------- start ----------"
if ($interface) {
    Write-Host "[$scriptName]  interface : $interface"
} else {
	$interface = 'powershell'
    Write-Host "[$scriptName]  interface : $interface (default)"
}

switch($interface){
    'powershell' {
		Write-Host "`n[$scriptName] Install Azure PowerShell commandlets`n"
		executeRetry 'Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Verbose -Force'
		executeRetry 'Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted'
		executeRetry 'Install-PackageProvider -Name NuGet -Confirm:$False'
		executeRetry 'Install-Module NuGet -Confirm:$False'
		executeRetry 'Install-Module AzureRM -Confirm:$False'
		executeRetry 'Install-Module Azure -Confirm:$False'
	}
    'cli' {
	    Write-Host "[$scriptName] Interface $interface is not yet implemented."
	}
	
    default {
	    Write-Host "[$scriptName] Interface $interface is not supported! Exit with LASTEXITCODE 3657"
	    exit 3657
    }
}

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0