function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
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