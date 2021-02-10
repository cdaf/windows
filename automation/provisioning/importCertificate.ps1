Param (
	[string]$certPath,
	[string]$pfxPassword,
	[string]$location,
	[string]$placement
)

cmd /c "exit 0"
$Error.Clear()
$scriptName = 'importCertificate.ps1'

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

Write-Host "`n[$scriptName] Requires elevated privilages"
Write-Host "`n[$scriptName] ---------- start ----------"
if ($certPath) {
	$certPath = Resolve-Path -Path $certPath
	Write-Host "[$scriptName] certPath    : $certPath"
} else {
	Write-Host "[$scriptName] certPath not supplied!"; exit 8610
}

if ($pfxPassword) {
	Write-Host "[$scriptName] pfxPassword : $pfxPassword"
} else {
	Write-Host "[$scriptName] pfxPassword not supplied!"; exit 8611
}

if ($location) {
	Write-Host "[$scriptName] location    : $location (CurrentUser or LocalMachine)"
} else {
	$location = 'CurrentUser'
	Write-Host "[$scriptName] location    : $location (default)"
}

if ($placement) {
	Write-Host "[$scriptName] placement   : $placement (e.g. My, WebHosting)"
} else {
	$placement = 'My'
	Write-Host "[$scriptName] placement   : $placement (default)"
}

if ( $location -eq 'LocalMachine') {
	$flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet
} else {
	$flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet
}

$pfx = executeReturn 'new-object System.Security.Cryptography.X509Certificates.X509Certificate2'
executeExpression "`$pfx.Import('$certPath', '$pfxPassword', `$flags)"

Write-Host "`n[$scriptName] Access the store ($location\$placement)"
$store = executeReturn "new-object System.Security.Cryptography.X509Certificates.X509Store('$placement', '$location')"
executeExpression '$store.open([System.Security.Cryptography.X509Certificates.OpenFlags]::MaxAllowed)'
executeExpression '$store.add($pfx)'
executeExpression '$store.close()'

Write-Host "`n[$scriptName] Import complete"
executeExpression "Get-ChildItem -path cert:\$location\$placement"

Write-Host "`n[$scriptName] ---------- stop -----------"
$error.clear()
exit 0