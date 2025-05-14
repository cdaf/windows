Param (
	[string]$spn,
	[string]$targetAccount
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
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE, $error[] = $error`n" -ForegroundColor Yellow
				$error.clear()
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName][WARN] $Error array populated but LASTEXITCODE not set, $error[] = $error`n" -ForegroundColor Yellow
			$error.clear()
		}
	}
}

$scriptName = 'setSPN.ps1'
Write-Host "`nConfigure SPN for double hop authentication. Perform on Domain Controller."
Write-Host "`n[$scriptName] ---------- start ----------"
if ($spn) {
    Write-Host "[$scriptName] spn           : $spn"
} else {
	$spn = 'MSSQLSvc/DB:1433'
    Write-Host "[$scriptName] spn           : $spn (default)"
}

if ($targetAccount) {
    Write-Host "[$scriptName] targetAccount : $targetAccount"
} else {
	$targetAccount = 'MSHOME\SQLSA'
    Write-Host "[$scriptName] targetAccount : $targetAccount (default)"
}

executeExpression "setspn.exe -a $spn $targetAccount"

Write-Host "`n[$scriptName] ---------- stop ----------`n"
