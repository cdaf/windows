Param (
	[string]$proxyURI
)

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

$scriptName = 'addDISM.ps1'

Write-Host "`n[$scriptName] ---------- start ----------`n"
if ($proxyURI) {
    Write-Host "[$scriptName] proxyURI                  : $proxyURI"
} else {
    Write-Host "[$scriptName] ERROR: proxyURI not passed, halting with LASTEXITCODE=110"; exit 110
}

if ($DefaultNetworkCredentials) {
    Write-Host "[$scriptName] DefaultNetworkCredentials : $DefaultNetworkCredentials"
} else {
	$DefaultNetworkCredentials = 'no'
    Write-Host "[$scriptName] DefaultNetworkCredentials : $DefaultNetworkCredentials (default)"
}

executeExpression "Add-Content $PROFILE `"[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('$proxyURI')`""

if ($DefaultNetworkCredentials -eq 'yes') {
	executeExpression "Add-Content $PROFILE `"[system.net.webrequest]::defaultwebproxy.credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials`""
}
executeExpression "Add-Content $PROFILE `"[system.net.webrequest]::defaultwebproxy.BypassProxyOnLocal = `$true`""

executeExpression "$PROFILE"

Write-Host "`n[$scriptName] List the resulting configuration ..."
[system.net.webrequest]::defaultwebproxy

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0