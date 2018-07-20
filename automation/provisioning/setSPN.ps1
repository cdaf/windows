# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

$scriptName = 'setSPN.ps1'
Write-Host
Write-Host "Configure SPN for double hop authentication. Perform on Domain Controller."
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$spn = $args[0]
if ($spn) {
    Write-Host "[$scriptName] spn           : $spn"
} else {
	$spn = 'MSSQLSvc/DB:1433'
    Write-Host "[$scriptName] spn           : $spn (default)"
}

$targetAccount = $args[1]
if ($targetAccount) {
    Write-Host "[$scriptName] targetAccount : $targetAccount"
} else {
	$targetAccount = 'SKY\SQLSA'
    Write-Host "[$scriptName] targetAccount : $targetAccount (default)"
}

executeExpression "setspn.exe -a $spn $targetAccount"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
