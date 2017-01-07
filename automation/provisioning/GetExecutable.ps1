function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
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

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

$fullpath = $mediaDir + '\' + $exename
if ( Test-Path $fullpath ) {
	Write-Host "[scriptName.ps1] $fullpath exists, download not required"
} else {

	$webclient = new-object system.net.webclient
	Write-Host "[$scriptName] $webclient.DownloadFile(`"$uri`", `"$fullpath`")"
	$webclient.DownloadFile("$uri", "$fullpath")
}

executeExpression "Copy-Item `'$fullpath`' `'$env:SYSTEMROOT`'"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
