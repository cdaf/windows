Param (
  [string]$mode,
  [string]$instance
)
$scriptName = 'sqlAuthMode.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($mode) {
    Write-Host "[$scriptName] mode     : $mode"
} else {
	$mode = 'Mixed'
    Write-Host "[$scriptName] mode     : $mode (default)"
}

if ($instance) {
    Write-Host "[$scriptName] instance : $instance"
} else {
	$instance = 'MSSQLSERVER'
    Write-Host "[$scriptName] instance : $instance (default)"
}

# SMO installed as part of Standard, connect to the local default instance
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")'
$srv = executeExpression 'new-Object Microsoft.SqlServer.Management.Smo.Server(".")'
executeExpression '$srv.Databases | Select name' # Establish connection
   
# Change the mode and restart the instance
executeExpression "`$srv.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode]::$mode"
executeExpression '$srv.Alter()'
executeExpression '$srv.Settings.LoginMode'
executeExpression "Restart-Service $instance"

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0