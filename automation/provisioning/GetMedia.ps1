Param (
  [string]$uri,
  [string]$mediaDir
)
$scriptName = 'GetMedia.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    return $output
}

Write-Host
Write-Host "[$scriptName] ---------- start ----------"
if ($uri) {
    Write-Host "[$scriptName] uri      : $uri"
} else {
    Write-Host "[$scriptName] uri not supplied, exiting"
    exit 101
}

if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = '/.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $uri $mediaDir`""
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

$filename = $uri.Substring($uri.LastIndexOf("/") + 1)
$fullpath = $mediaDir + '\' + $filename
if ( Test-Path $fullpath ) {
	Write-Host "[scriptName.ps1] $fullpath exists, download not required"
} else {

	$webclient = executeExpression "new-object system.net.webclient"
	executeExpression "`$webclient.DownloadFile(`"$uri`", `"$fullpath`")"
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
