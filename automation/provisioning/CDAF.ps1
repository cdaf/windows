Param (
	[string]$userName,
	[string]$userPass,
	[string]$workspace,
	[string]$OPT_ARG
)
$scriptName = 'CDAF.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 10 }
	} catch { echo $_.Exception|format-list -force; exit 11 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 12 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

cmd /c "exit 0" # Clear from any previously failed run

Write-Host "`n[$scriptName] Execute the Continous Delivery Automation Framework for the solution."
Write-Host "[$scriptName] This process is dependant on the solution being synchonised onto the"
Write-Host "[$scriptName] `"build server`" using Vagrant and VirtualBox, which maps the local workspace"
Write-Host "[$scriptName] at C:\vagrant. If this is not used, then the workspace must be passed."
Write-Host "`n[$scriptName] By default the emulation is performed using the local Vagrant user, however"
Write-Host "[$scriptName] alternate credentials can be passed and a remote PowerShell connection will"
Write-Host "[$scriptName] be attempted, connecting back to the `"build server`" via the localhost adapter."
Write-Host "`n[$scriptName] ---------- start ----------`n"
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

if ($OPT_ARG) {
    Write-Host "[$scriptName] OPT_ARG   : $OPT_ARG"
} else {
    Write-Host "[$scriptName] OPT_ARG   : (not supplied)"
}

if ($userName) {

	# To capture the exit code of the remote execution, the LASTEXITCODE is stored in an environment variable, and retrieved in a subsequent
	# call, if return of LASTEXITCODE is attempted during excution, all standard out is consumed by the result.
	$securePassword = executeExpression "ConvertTo-SecureString `$userPass -asplaintext -force"
	$cred = executeExpression "New-Object System.Management.Automation.PSCredential (`"$userName`", `$securePassword)"
	$script = [scriptblock]::Create("cd $workspace; .\automation\cdEmulate.bat $OPT_ARG; [Environment]::SetEnvironmentVariable(`'PREVIOUS_EXIT_CODE`', `"`$LASTEXITCODE`", `'User`')")
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
	& .\automation\cdEmulate.bat $OPT_ARG
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