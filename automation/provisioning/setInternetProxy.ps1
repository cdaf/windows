Param (
	[string]$httpProxy,
	[string]$automaticeConfigurationScript
)

cmd /c "exit 0"
$scriptName = 'setInternetProxy.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "`n[$scriptName] ---------- start ----------`n"
if ($httpProxy) {
    Write-Host "[$scriptName] httpProxy                     : $httpProxy (can be space separated list)"
} else {
	if ($env:http_proxy) {
		$httpProxy = $env:http_proxy
	    Write-Host "[$scriptName] httpProxy                     : $httpProxy (not passed, but derived from `$env:http_proxy)"
	} else {
	    Write-Host "[$scriptName] httpProxy not passed and unable to derive from `$env:http_proxy, exit without attempting any changes" -ForegroundColor 'Yellow' 
	}
}

if ($automaticeConfigurationScript) {
    Write-Host "[$scriptName] automaticeConfigurationScript : $automaticeConfigurationScript"
} else {
    Write-Host "[$scriptName] automaticeConfigurationScript : (not supplied)"
}

$protocol,$prefix,$port = $httpProxy.split(':')
$address = $prefix.Replace('/', '')
$regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
executeExpression "Set-ItemProperty -path '$regKey' ProxyEnable -value 1"
executeExpression "Set-ItemProperty -path '$regKey' ProxyServer -value '${address}:${port}'"

Write-Host "`n[$scriptName] List current settings before changing`n"
executeExpression "netsh winhttp show proxy"
executeExpression "netsh winhttp set proxy '${address}:${port}'"

if ($automaticeConfigurationScript) {
    executeExpression "Set-ItemProperty -path $regKey AutoConfigURL -Value $automaticeConfigurationScript"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0 