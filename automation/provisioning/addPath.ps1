Param (
	[string]$directoryName
)

cmd /c "exit 0"
$Error.Clear()

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1112 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red ; $error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				$error
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName] `$error[] = $error"; exit 1113
		}
	}
}

$scriptName = 'addPath.ps1'
Write-Host "`n[$scriptName] ---------- start ----------"
if ($directoryName) {
    Write-Host "[$scriptName] directoryName : $directoryName"
} else {
    Write-Host "[$scriptName] directoryName not supplied, exiting!"
    exit 2365
}

# Append Directory to PATH
executeExpression "[Environment]::SetEnvironmentVariable(`'Path`', `$env:Path + `";$directoryName`", [EnvironmentVariableTarget]::Machine)"

# Reload the path (without logging off and back on)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "`n[$scriptName] ---------- stop -----------`n"
