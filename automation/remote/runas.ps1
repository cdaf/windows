Param (
	[string]$command,
	[string]$userName,
	[string]$userPass,
	[string]$workspace
)
$scriptName = 'runas.ps1'
cmd /c "exit 0" # Clear from any previously failed run

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 10 }
	} catch { echo $_.Exception|format-list -force; exit 11 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 12 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------`n"
if ($command) {
    Write-Host "[$scriptName] command   : $command"
} else {
    Write-Host "[$scriptName] command   : (not supplied)"
}

if ($userName) {
    Write-Host "[$scriptName] userName  : $userName"
} else {
    Write-Host "[$scriptName] userName  : not supplied, use local"
}

if ($userPass) {
    Write-Host "[$scriptName] userPass  : **********"
} else {
    Write-Host "[$scriptName] userPass  : not supplied, use local"
}

if ($workspace) {
    Write-Host "[$scriptName] workspace : $workspace"
} else {
	$workspace = 'c:\vagrant'
    Write-Host "[$scriptName] workspace : $workspace (default)"
}

if ($userName) {

	# To capture the exit code of the remote execution, the LASTEXITCODE is stored in an environment variable, and retrieved in a subsequent
	# call, if return of LASTEXITCODE is attempted during excution, all standard out is consumed by the result.
	$securePassword = executeExpression "ConvertTo-SecureString `$userPass -asplaintext -force"
	$cred = executeExpression "New-Object System.Management.Automation.PSCredential (`"$userName`", `$securePassword)"
	$script = [scriptblock]::Create("cd $workspace; $command; [Environment]::SetEnvironmentVariable(`'PREVIOUS_EXIT_CODE`', `"`$LASTEXITCODE`", `'User`')")
	Write-Host "[$scriptName] Invoke-Command -ComputerName localhost -Credential `$cred -ScriptBlock $script"
	try {
		Invoke-Command -ComputerName localhost -Credential $cred -ScriptBlock $script
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1090 }
	} catch { echo $_.Exception|format-list -force; exit 1190 }
	
	Write-Host "[$scriptName] `$LASTEXITCODE = Invoke-Command -ComputerName localhost -Credential `$cred -ScriptBlock { [Environment]::GetEnvironmentVariable('PREVIOUS_EXIT_CODE', 'User')} "
	try {
	$LASTEXITCODE = Invoke-Command -ComputerName localhost -Credential $cred -ScriptBlock { [Environment]::GetEnvironmentVariable('PREVIOUS_EXIT_CODE', 'User')}
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1091 }
	} catch { echo $_.Exception|format-list -force; exit 1191 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }

} else {

	Write-Host "[$scriptName] Execute as $(whoami) using workspace ($workspace)"
	executeExpression "cd $workspace"
	executeExpression $command
	if($LASTEXITCODE -ne 0){
	    write-host "[$scriptName] CURRENT_USER_NON_ZERO_EXIT & .\automation\cdEmulate.bat $OPT_ARG" -ForegroundColor Magenta
	    write-host "[$scriptName]   Exit with `$LASTEXITCODE $LASTEXITCODE" -ForegroundColor Red
	    exit $LASTEXITCODE
	}
    if(!$?){ 
	    write-host "[$scriptName] CURRENT_USER_EXEC_FALSE & .\automation\cdEmulate.bat $OPT_ARG" -ForegroundColor Magenta
	    write-host "[$scriptName]   Exit with `$LASTEXITCODE 900" -ForegroundColor Red
	    exit 900
	}
}

Write-Host "`n[$scriptName] ---------- stop -----------"
$error.clear()
exit 0