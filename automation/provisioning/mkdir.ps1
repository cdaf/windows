function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
}

$scriptName = 'mkdir.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
Write-Host
$directoryName = $args[0]
if ($directoryName) {
    Write-Host "[$scriptName] directoryName : $directoryName"
} else {
    Write-Host "[$scriptName] directoryName not supplied, exiting!"
    exit 100
}

if ( Test-Path $directoryName ) {
	Write-Host "[$scriptName] Directory $directoryName already exists, no action attempted."
} else {
	executeExpression "New-Item -ItemType Directory -Force -Path `'$directoryName`'"
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host