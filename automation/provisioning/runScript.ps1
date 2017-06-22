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

$scriptName = 'runScript.ps1'
Write-Host
Write-Host "[$scriptName] Seeds the runscript."
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$scriptPath = $args[0]
if ($scriptPath) {
    Write-Host "[$scriptName] scriptPath   : $scriptPath (choices $configChoices)"
} else {
	$scriptPath = 'C:\portable.ps1'
    Write-Host "[$scriptName] scriptPath   : $scriptPath (default, choices $configChoices)"
}

if (Test-Path "$scriptPath") {
    Write-Host "`n[$scriptName] Script exists ($scriptPath), delete for new run."
	executeExpression "Remove-Item `"$scriptPath`""
}

executeExpression "[Environment]::SetEnvironmentVariable('PROV_SCRIPT_PATH', '$scriptPath', 'Machine')"
Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $featureList $optParam`""

$literal = 'f' + 'unction executeExpression ($expression) {'

Add-Content "$scriptPath" $literal 
Add-Content "$scriptPath" '	$error.clear()'
Add-Content "$scriptPath" '	$lastExitCode = 0'
Add-Content "$scriptPath" '	Write-Host "[$scriptName] $expression"'
Add-Content "$scriptPath" '	try {'
Add-Content "$scriptPath" '		Invoke-Expression $expression'
Add-Content "$scriptPath" '	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }'
Add-Content "$scriptPath" '	} catch { echo $_.Exception|format-list -force; exit 2 }'
Add-Content "$scriptPath" '    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }'
Add-Content "$scriptPath" '    if ( $lastExitCode -ne 0 ) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode "; exit $lastExitCode }'
Add-Content "$scriptPath" '}'
Add-Content "$scriptPath" '$scriptName = $MyInvocation.MyCommand.Name'

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
