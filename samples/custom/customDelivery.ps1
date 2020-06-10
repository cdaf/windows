Param (
	[string]$SOLUTION,
	[string]$BUILD,
	[string]$ENVIRONMENT
)

$Error.Clear()
cmd /c "exit 0"
$scriptName = 'customDelivery.ps1'

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
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE, $error[] =`n" -ForegroundColor Yellow
				$error
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName][WARN] $Error array populated but LASTEXITCODE not set, $error[] =`n" -ForegroundColor Yellow
			$error
		}
	}
}

Write-Host "`n[$scriptName] ---------- start ----------`n"
Write-Host "[$scriptName] SOLUTION    : $SOLUTION"
Write-Host "[$scriptName] BUILD       : $BUILD"
Write-Host "[$scriptName] ENVIRONMENT : $ENVIRONMENT"
Write-Host "[$scriptName] TARGET      : $TARGET"

& ./Transform.ps1 $TARGET | ForEach-Object { invoke-expression $_ }

executeExpression "dir"

Write-Host "`n[$scriptName] ---------- stop ----------"
