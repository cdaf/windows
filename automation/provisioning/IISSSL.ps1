Param (
  [string]$thumbPrint,
  [string]$ip,
  [string]$port,
  [string]$siteName,
  [string]$location,
  [string]$placement,
  [string]$hostHeader
)

cmd /c "exit 0"
$Error.Clear()
$scriptName = 'IISSSL.ps1'

# Extension to capture output and return for use in variables
function executeReturn ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		$output = Invoke-Expression "$expression 2> `$null"
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch {
		Write-Host "[$scriptName][EXCEPTION] List exception and error array (if populated) and exit with LASTEXITCODE 1112" -ForegroundColor Red
		Write-Host $_.Exception|format-list -force
		if ( $error ) { Write-Host "[$scriptName][EXCEPTION] `$Error = $Error" ; $Error.clear() }
		exit 1112
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName][EXIT] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red
			if ( $error ) { Write-Host "[$scriptName][EXIT] `$Error = $Error" ; $Error.clear() }
			exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				Write-Host "[$scriptName][WARN] `$Error = $Error" ; $Error.clear()
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				Write-Host "[$scriptName][ERROR] `$Error = $error"; $Error.clear()
				Write-Host "[$scriptName][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting with LASTEXITCODE 1113 ..."; exit 1113
	    	} else {
		    	Write-Host "[$scriptName][WARN] `$Error = $error" ; $Error.clear()
	    	}
		}
	}
    return $output
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression "$expression 2> `$null"
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch {
		Write-Host "[$scriptName][EXCEPTION] List exception and error array (if populated) and exit with LASTEXITCODE 1112" -ForegroundColor Red
		Write-Host $_.Exception|format-list -force
		if ( $error ) { Write-Host "[$scriptName][EXCEPTION] `$Error = $Error" ; $Error.clear() }
		exit 1112
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName][EXIT] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red
			if ( $error ) { Write-Host "[$scriptName][EXIT] `$Error = $Error" ; $Error.clear() }
			exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				Write-Host "[$scriptName][WARN] `$Error = $Error" ; $Error.clear()
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				Write-Host "[$scriptName][ERROR] `$Error = $error"; $Error.clear()
				Write-Host "[$scriptName][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting with LASTEXITCODE 1113 ..."; exit 1113
	    	} else {
		    	Write-Host "[$scriptName][WARN] `$Error = $error" ; $Error.clear()
	    	}
		}
	}
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($thumbPrint) {
    Write-Host "[$scriptName] thumbPrint : $thumbPrint"
} else {
    Write-Host "[$scriptName] thumbPrint not passed, exiting with LASTEXITCODE = 53"; exit 53
}
if ($ip) {
    Write-Host "[$scriptName] ip         : $ip"
} else {
	$ip = '0.0.0.0'
    Write-Host "[$scriptName] ip         : $ip (default)"
}
if ($port) {
    Write-Host "[$scriptName] port       : $port"
} else {
	$port = '443'
    Write-Host "[$scriptName] port       : $port (default)"
}
if ($siteName) {
    Write-Host "[$scriptName] siteName   : $siteName"
} else {
	$siteName = 'Default Web Site'
    Write-Host "[$scriptName] siteName   : $siteName (default)"
}
if ($location) {
	Write-Host "[$scriptName] location   : $location (CurrentUser or LocalMachine)"
} else {
	$location = 'LocalMachine'
	Write-Host "[$scriptName] location   : $location (default)"
}
  
if ($placement) {
	Write-Host "[$scriptName] placement  : $placement (e.g. My, WebHosting)"
} else {
	$placement = 'My'
	Write-Host "[$scriptName] placement  : $placement (default)"
}
  
if ($hostHeader) {
	Write-Host "[$scriptName] hostHeader : $hostHeader (e.g. My, WebHosting)`n"
} else {
	Write-Host "[$scriptName] hostHeader : (not supplied)`n"
}

executeExpression 'import-module WebAdministration'

Write-Host "`n[$scriptName] Existing http.sys bindings`n"
Write-Host 'Get-ChildItem "IIS:\SslBindings\"'
try {
	Get-ChildItem "IIS:\SslBindings\"
} catch {
	$_.ErrorDetails.Message.message
}

$binding = "IIS:\SslBindings\$ip!$port"
try {
	if ( test-path $binding ) { 
		Write-Host "DEBUG Remove-Item '$binding'"
		executeExpression "Remove-Item '$binding'"
	}
} catch {
	Write-Host "DEBUG test-path $binding threw exception, this is likely a bitwise issue, with PowerShell falling back to 32bit."
	Write-Host $_.Exception|format-list -force
}

$cert = executeReturn "Get-ChildItem -Path Cert:\$location\$placement\$thumbPrint"


executeExpression "New-Item '$binding' -Value `$cert"

if ( $ip -eq '0.0.0.0' ) {
	$ip = '*'
}

if ( $hostHeader ) {
	$bindCheck = executeReturn "Get-WebBinding -Name '$siteName' -HostHeader '$hostHeader' -Protocol https"
	if ( $bindCheck ) {
		executeExpression "Remove-WebBinding -Name '$siteName' -HostHeader '$hostHeader' -Protocol https"
	}
	executeExpression "New-WebBinding -Name '$siteName' -IP '$ip' -Port '$port' -HostHeader '$hostHeader' -Protocol https"
} else {
	$bindCheck = executeReturn "Get-WebBinding -Name '$siteName' -Protocol https"
	if ( $bindCheck ) {
		executeExpression "Remove-WebBinding -Name '$siteName' -Protocol https"
	}
	executeExpression "New-WebBinding -Name '$siteName' -IP '$ip' -Port '$port' -Protocol https"
}

Write-Host "`n[$scriptName] http.sys bindings after`n"
executeExpression 'Get-ChildItem "IIS:\SslBindings\"'

executeExpression "Get-WebBinding -Name '$siteName'"

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0