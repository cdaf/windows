Param (
  [string]$mode,
  [string]$instance
)
$scriptName = 'sqlAuthMode.ps1'
cmd /c "exit 0"

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

Write-Host "`n[$scriptName] Because the instance service has to be restarted, this script only supports execution on the SQL host itself"
Write-Host "`n[$scriptName] ---------- start ----------"
if ($mode) {
    Write-Host "[$scriptName] mode     : $mode"
} else {
	$mode = 'Mixed'
    Write-Host "[$scriptName] mode     : $mode (default)"
}

if ($instance) {
	$sqlinstance = 'MSSQL$' + $instance
    Write-Host "[$scriptName] instance : $sqlinstance"
} else {
	$sqlinstance = 'MSSQLSERVER'
    Write-Host "[$scriptName] instance : $sqlinstance (default)"
}

# SMO installed as part of Standard, connect to the local default instance
executeExpression '[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")'
if ($instance) {
	$srv = executeExpression 'new-Object Microsoft.SqlServer.Management.Smo.Server(".\$instance")'
} else {
	$srv = executeExpression 'new-Object Microsoft.SqlServer.Management.Smo.Server(".")'
}

executeExpression '$srv.Databases | Select name' # Establish connection
   
# Change the mode and restart the instance
executeExpression "`$srv.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode]::$mode"
executeExpression '$srv.Alter()'
executeExpression '$srv.Settings.LoginMode'
executeExpression "Restart-Service '$sqlinstance'"

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0