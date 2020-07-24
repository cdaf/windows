Param (
	[string]$variable,
	[string]$value,
	[string]$target,
	[string]$secret
)

cmd /c "exit 0"
$scriptName = 'setenv.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($variable) {
    Write-Host "[$scriptName] variable : $variable"
} else {
	$mediaDir = "$env:TEMP"
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

if ($value) {
	if ($secret -eq 'yes') {
		Write-Host "[$scriptName] value    : **********************"
	} else {
		Write-Host "[$scriptName] value    : $value"
	}
} else {
    Write-Host "[$scriptName] value required, exiting!"
    exit 101
}

if ($target) {
    Write-Host "[$scriptName] target   : $target"
} else {
	$target = 'user'
    Write-Host "[$scriptName] target   : $target (default, choices user or machine)"
}


Write-Host
executeExpression "[Environment]::SetEnvironmentVariable(`'$variable`', `$value, `'$target`')"
executeExpression "`$env:$variable = [Environment]::GetEnvironmentVariable(`'$variable`', `'$target`')"

Write-Host "`n[$scriptName] ---------- stop -----------`n"