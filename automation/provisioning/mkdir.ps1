# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	$LASTEXITCODE = 0
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 10 }
	} catch { echo $_.Exception|format-list -force; exit 11 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 12 }
    if ( $LASTEXITCODE -ne 0 ) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

$scriptName = 'mkdir.ps1'
Write-Host "`n[$scriptName] ---------- start ----------`n"
$directoryName = $args[0]
if ($directoryName) {
    Write-Host "[$scriptName] directoryName : $directoryName"
} else {
    Write-Host "[$scriptName] directoryName not supplied, exiting!"
    exit 100
}

# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $directoryName`""
}

if ( Test-Path $directoryName ) {
	Write-Host "[$scriptName] Directory $directoryName already exists, no action attempted."
} else {
	executeExpression "New-Item -ItemType Directory -Force -Path `'$directoryName`'"
}
	$newDir = executeExpression "New-Item -ItemType Directory -Force -Path `'$directoryName`'"
	Write-Host "Created $($newDir.FullName)"

Write-Host "`n[$scriptName] ---------- stop -----------"
