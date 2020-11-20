Param (
  [string]$thumbPrint,
  [string]$ip,
  [string]$port,
  [string]$siteName,
  [string]$location,
  [string]$placement
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
		Write-Host "[$scriptName][EXCEPTION] List exception and error array (if populated) and exit with LASTEXITCIDE 1112" -ForegroundColor Red
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
		Write-Host "[$scriptName][EXCEPTION] List exception and error array (if populated) and exit with LASTEXITCIDE 1112" -ForegroundColor Red
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
  
Write-Host
executeExpression 'import-module WebAdministration'

Write-Host
if (test-path IIS:\SslBindings\$ip!$port) { 
	executeExpression "Remove-Item IIS:\SslBindings\$ip!$port"
}

$cert = executeReturn "Get-ChildItem -Path Cert:\$location\$placement\$thumbPrint"
executeExpression "New-Item 'IIS:\SslBindings\$ip!$port' -Value `$cert"

if ( $ip -eq '0.0.0.0' ) {
	$ip = '*'
}
$bindCheck = executeReturn "Get-WebBinding -Name '$siteName' -Protocol https"
if ( $bindCheck ) {
	executeExpression "Remove-WebBinding -Name '$siteName' -Protocol https"
}
executeExpression "New-WebBinding -Name '$siteName' -IP '$ip' -Port '$port' -Protocol https"
executeExpression "Get-WebBinding -Name '$siteName'"

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0