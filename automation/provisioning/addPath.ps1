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

$scriptName = 'addPath.ps1'
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

# Append Directory to PATH
executeExpression "[Environment]::SetEnvironmentVariable(`'Path`', `$env:Path + `";$directoryName`", [EnvironmentVariableTarget]::Machine)"

# Reload the path (without logging off and back on)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host