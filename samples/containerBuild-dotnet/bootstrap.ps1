Param (
	[string]$restart
)

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

$scriptName = 'bootstrap-runner.ps1'
cmd /c "exit 0" # ensure LASTEXITCODE is 0
$error.clear()

Write-Host "`n[$scriptName] ---------- start ----------"

$env:CDAF_PATH = 'automation'
executeExpression '. { iwr -useb https://raw.githubusercontent.com/cdaf/windows/master/install.ps1 } | iex'
# executeExpression '. { iwr -useb https://cdaf.io/static/app/downloads/cdaf.ps1 } | iex'
executeExpression '.\automation\provisioning\base.ps1 nuget.commandline'

executeExpression 'nuget.exe install Microsoft.TestPlatform'
executeExpression ".\automation\provisioning\addPath.ps1 '$((Get-ChildItem -Recurse "C:\solution" -Filter "vstest.console.exe").FullName)'"
executeExpression ".\automation\provisioning\setenv.ps1 VSTEST_CONSOLE '$((Get-ChildItem -Recurse "C:\solution" -Filter "vstest.console.exe").FullName)'"

executeExpression '.\automation\provisioning\base.ps1 vswhere'

executeExpression '.\automation\provisioning\installAgent.ps1 -version 2.210.0'

Write-Host "`n[$scriptName] ---------- stop ----------"
