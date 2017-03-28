# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
}

$scriptName = 'GetExecutable.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$exename = $args[0]
if ($exename) {
    Write-Host "[$scriptName] exename  : $exename"
} else {
	$exename = 'Database.exe'
    Write-Host "[$scriptName] exename  : $exename (default)"
}

$mediaDir = $args[1]
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = '/.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

$uri = $args[2]
if ($uri) {
    Write-Host "[$scriptName] uri      : $uri"
} else {
	$uri = 'http://cdaf.azurewebsites.net/content/Database.exe'
    Write-Host "[$scriptName] uri      : $uri (default)"
}

$useCache = $args[3]
if ($useCache) {
    Write-Host "[$scriptName] useCache : $useCache"
} else {
	$useCache = 'yes'
    Write-Host "[$scriptName] useCache : (not passed, default to Yes)"
}

# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $exename $mediaDir $uri $useCache`""
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

Write-Host
$fullpath = $mediaDir + '\' + $exename
if ( Test-Path $fullpath ) {
	if ($useCache -match 'yes') {
		Write-Host "[$scriptName] $fullpath exists, download not required"
	} else {
		Write-Host "[$scriptName] $fullpath exist, but useCache set to $useCache, so replacing file..."
		executeExpression "(New-Object System.Net.WebClient).DownloadFile(`$uri, `$fullpath)" 
	}
} else {

	executeExpression "(New-Object System.Net.WebClient).DownloadFile(`$uri, `$fullpath)" 

}

executeExpression "Copy-Item `'$fullpath`' `'$env:SYSTEMROOT`'"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
