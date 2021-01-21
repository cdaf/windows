Param (
	[string]$npmPackages
)

cmd /c "exit 0"
$scriptName = 'bootstrapJDK.ps1'

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
if ($npmPackages) {
    Write-Host "[$scriptName] npmPackages : $npmPackages"
} else {
    Write-Host "[$scriptName] npmPackages : (not supplied, NodeJS and NPM will not be installed)"
}

Write-Host "`n[$scriptName] Set TLS to version 1.2 or higher"
executeExpression "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls11,Tls12'"

Write-Host "`n[$scriptName] If default vagrant mapping (C:\vagrant) is found, set atomic path to absolute, otherwise use relative`n"
if ( Test-Path '/vagrant/automation' ) {
	$atomicPath = '/vagrant/automation'
 } else {
	. { iwr -useb https://raw.githubusercontent.com/cdaf/windows/master/installCDAF.ps1 } | iex
	$atomicPath = "${env:USERPROFILE}/.cdaf"
}

Write-Host "`n[$scriptName] `$atomicPath = $atomicPath"
executeExpression "$atomicPath\provisioning\addpath.ps1 $atomicPath"
executeExpression "$atomicPath\provisioning\addpath.ps1 $atomicPath\provisioning"

$filename = "${env:USERPROFILE}/.m2/settings.xml"
if ( Test-Path $filename ) {
	Write-Host "`n[$scriptName] $filename exists, will not replace"
} else {
	executeExpression "mkdir $(Split-Path -Path $filename)"
	executeExpression "cp ./settings.xml $filename"
}

Write-Host "[$scriptName] Install Oracle Java & Maven, using proxy if defined (`$env:http_proxy)`n"
if ($env:http_proxy) {
	$optionalArg = "-proxy '$env:http_proxy'"
}

Write-Host "`n[$scriptName] Will use local media cach (C:\.provision) if available"
executeExpression "$atomicPath\provisioning\base.ps1 'adoptopenjdk8'"
executeExpression "$atomicPath\provisioning\installApacheMaven.ps1 $optionalArg"

if ($npmPackages) {
	Write-Host "`n[$scriptName] Install NodeJS and requested packages (NPM uses Git as transport mechanism)"
	executeExpression "$atomicPath\provisioning\base.ps1 'nodejs git'"
	foreach ( $package in $npmPackages.Split()) {
		executeExpression "npm install -g $package"
	}
}
executeExpression "$atomicPath\remote\capabilities.ps1"

Write-Host "`n[$scriptName] ---------- stop ----------"
