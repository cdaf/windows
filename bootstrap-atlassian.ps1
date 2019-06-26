Param (
	[string]$sqlSA,
	[string]$port
)

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

$scriptName = 'bootstrap-atlassian.ps1'
cmd /c "exit 0" # ensure LASTEXITCODE is 0

Write-Host "`n[$scriptName] ---------- start ----------"
if ($sqlSA) {
    Write-Host "[$scriptName] sqlSA  : $sqlSA"
} else {
    Write-Host "[$scriptName] sqlSA  : (not supplied, only reverse proxy will be installed)"
}

if ($port) {
    Write-Host "[$scriptName] port : $port"
} else {
	$port = '8080'
    Write-Host "[$scriptName] port : $port (not supplied so set to default)"
}

Write-Host "[$scriptName] pwd    = $(pwd)"
Write-Host "[$scriptName] whoami = $(whoami)"

if ( Test-Path "./automation/provisioning" ) {
	$atomicPath = '.'
} else {
	if ( Test-Path "/vagrant" ) {
		$atomicPath = '/vagrant'
	} else {
	    Write-Host "[$scriptName] Cannot find CDAF directories in workspace or /vagrant, so downloading stable release from http://cdaf.io"
		Write-Host "[$scriptName] Download Continuous Delivery Automation Framework"
		Write-Host "[$scriptName] `$zipFile = 'WU-CDAF.zip'"
		$zipFile = 'WU-CDAF.zip'
		Write-Host "[$scriptName] `$url = `"http://cdaf.io/static/app/downloads/$zipFile`""
		$url = "http://cdaf.io/static/app/downloads/$zipFile"
		executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$PWD\$zipFile')"
		executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
		executeExpression '[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$zipfile", "$PWD")'
		executeExpression 'cat .\automation\CDAF.windows'
		$atomicPath = '.'
	}
}
Write-Host "[$scriptName] `$atomicPath = $atomicPath"

executeExpression "$atomicPath\automation\provisioning\InstallIIS.ps1 -management yes"

## Install Application Request Routing (ARR)
executeExpression "Stop-Service W3SVC"
executeExpression "$atomicPath\automation\provisioning\GetMedia.ps1 http://download.microsoft.com/download/E/9/8/E9849D6A-020E-47E4-9FD0-A023E99B54EB/requestRouter_amd64.msi"
executeExpression "$atomicPath\automation\provisioning\installMSI.ps1 C:\.provision\requestRouter_amd64.msi"
executeExpression "$atomicPath\automation\provisioning\GetMedia.ps1  https://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi"
executeExpression "$atomicPath\automation\provisioning\installMSI.ps1 C:\.provision\rewrite_amd64.msi"
executeExpression "Start-Service W3SVC"

executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "<?xml version=`"1.0`" encoding=`"UTF-8`"?>"'
executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "<configuration>"'
executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "    <system.webServer>"'
executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "        <rewrite>"'
executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "            <rules>"'
executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "                <clear />"'
executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "                <rule name=`"ReverseProxyInboundRule1`" stopProcessing=`"true`">"'
executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "                    <match url=`"(.*)`" />"'
executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "                    <conditions logicalGrouping=`"MatchAll`" trackAllCaptures=`"false`" />"'
executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "                    <action type=`"Rewrite`" url=`"http://localhost:$port/{R:1}`" />"'
executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "                </rule>"'
executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "            </rules>"'
executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "        </rewrite>"'
executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "    </system.webServer>"'
executeExpression 'Add-Content C:\inetpub\wwwroot\web.config "</configuration>"'

if ($sqlSA) {
	$msa = $sqlSA + '$'
	Write-Host "[$scriptName] Using managed service account $msa"
	
	## Mount Install media to D:\ (default for script), NOTE the '$' after the managed service account
	executeExpression "$atomicPath\automation\provisioning\installSQLServer.ps1 '$msa'"
	
	# SMO installed as part of Standard, connect to the local default instance
	executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")'
	executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")'
	$srv = executeExpression 'new-Object Microsoft.SqlServer.Management.Smo.Server(".")'
	
	# Change the mode and restart the instance
	executeExpression '$srv.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode]::Mixed'
	executeExpression '$srv.Alter()'
	executeExpression '$srv.Settings.LoginMode'
	executeExpression "Restart-Service MSSQLSERVER"
	
	# Allow remote access to the Database for SSMS to migrate the database
	executeExpression "$atomicPath\automation\provisioning\openFirewallPort.ps1 1433 SQL"
	
	# Adopt Open JDK (migrating from Oracle JDK)
	executeExpression "$atomicPath\automation\provisioning\base.ps1 adoptopenjdk -version 8.192"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
