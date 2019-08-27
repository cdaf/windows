Param (
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
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

$scriptName = 'bootstrap-arr.ps1'
cmd /c "exit 0" # ensure LASTEXITCODE is 0

Write-Host "`n[$scriptName] ---------- start ----------"
if ($port) {
    Write-Host "[$scriptName] port : $port"
} else {
	$port = '8080'
    Write-Host "[$scriptName] port : $port (not supplied so set to default)"
}

Write-Host "[$scriptName] pwd    = $(pwd)"
Write-Host "[$scriptName] whoami = $(whoami)"

if ( Test-Path ".\automation\provisioning" ) {
	$atomicPath = '.'
} else {
	if ( Test-Path "C:\vagrant\automation\provisioning" ) {
		$atomicPath = 'C:\vagrant\automation\provisioning'
	} else {
	    Write-Host "[$scriptName] Cannot find CDAF directories in workspace or C:\vagrant, so downloading stable release from http://cdaf.io"
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

Write-Host "`n[$scriptName] ---------- stop ----------"
