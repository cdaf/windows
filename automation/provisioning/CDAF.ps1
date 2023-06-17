Param (
	[string]$userName,
	[string]$userPass,
	[string]$workspace,
	[string]$action
)
$scriptName = 'CDAF.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[executeExpression][$(Get-date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 10 }
	} catch { Write-Output $_.Exception|format-list -force; exit 11 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 12 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

function executeReturn ($expression) {
	$error.clear()
	Write-Host "[executeReturn][$(Get-date)] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 10 }
	} catch { Write-Output $_.Exception|format-list -force; exit 11 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 12 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}


cmd /c "exit 0" # Clear from any previously failed run

Write-Host "`n[$scriptName] Execute the Continuous Delivery Automation Framework for the solution."
Write-Host "[$scriptName] This process is dependent on the solution being synchonised onto the"
Write-Host "[$scriptName] `"build server`" using Vagrant and VirtualBox, which maps the local workspace"
Write-Host "[$scriptName] at C:\vagrant. If this is not used, then the workspace must be passed."
Write-Host "`n[$scriptName] By default the emulation is performed using the local Vagrant user, however"
Write-Host "[$scriptName] alternate credentials can be passed and a remote PowerShell connection will"
Write-Host "[$scriptName] be attempted, connecting back to the `"build server`" via the localhost adapter."
Write-Host "`n[$scriptName] ---------- start ----------`n"
if ($userName) {
    Write-Host "[$scriptName] userName             : $userName"
} else {
    Write-Host "[$scriptName] userName             : not supplied, use local"
}

if ($userPass) {
    Write-Host "[$scriptName] userPass             : **********"
} else {
    Write-Host "[$scriptName] userPass             : not supplied, use local"
}

if ($workspace) {
    Write-Host "[$scriptName] workspace            : $workspace"
} else {
	$workspace = 'c:\vagrant'
    Write-Host "[$scriptName] workspace            : $workspace (default)"
}

if ($action) {
    Write-Host "[$scriptName] action               : $action"
} else {
    Write-Host "[$scriptName] action               : (not supplied)"
}

if ($env:CDAF_AUTOMATION_ROOT) {
	Write-Host "[$scriptName] CDAF_AUTOMATION_ROOT : $env:CDAF_AUTOMATION_ROOT (using environment variable"
} else {
	$env:CDAF_AUTOMATION_ROOT = '.\automation'
	Write-Host "[$scriptName] CDAF_AUTOMATION_ROOT : $env:CDAF_AUTOMATION_ROOT (default)"
}

if ($userName) {

	# To capture the exit code of the remote execution, the LASTEXITCODE is stored in an environment variable, and retrieved in a subsequent
	# call, if return of LASTEXITCODE is attempted during excution, all standard out is consumed by the result.
	$securePassword = executeReturn "ConvertTo-SecureString `$userPass -asplaintext -force"
	$cred = executeReturn "New-Object System.Management.Automation.PSCredential (`"$userName`", `$securePassword)"
	$script = [scriptblock]::Create("cd $workspace; $env:CDAF_AUTOMATION_ROOT\cdEmulate.bat $action; [Environment]::SetEnvironmentVariable(`'PREVIOUS_EXIT_CODE`', `"`$LASTEXITCODE`", `'User`')")
	Write-Host "[$scriptName] Invoke-Command -ComputerName localhost -Credential `$cred -ScriptBlock $script"
	try {
		Invoke-Command -ComputerName localhost -Credential $cred -ScriptBlock $script
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 11091 }
	} catch { echo $_.Exception|format-list -force; exit 11092 }
	
	Write-Host "[$scriptName] `$LASTEXITCODE = Invoke-Command -ComputerName localhost -Credential `$cred -ScriptBlock { [Environment]::GetEnvironmentVariable('PREVIOUS_EXIT_CODE', 'User')} "
	try {
	$LASTEXITCODE = Invoke-Command -ComputerName localhost -Credential $cred -ScriptBlock { [Environment]::GetEnvironmentVariable('PREVIOUS_EXIT_CODE', 'User')}
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 11092 }
	} catch { Write-Output $_.Exception|format-list -force; exit 11093 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }

} else {

	Write-Host "[$scriptName] Execute as $(whoami) using workspace ($workspace)"
	executeExpression "cd $workspace"
	executeExpression "& $env:CDAF_AUTOMATION_ROOT\cdEmulate.bat $action"
}

Write-Host "`n[$scriptName] ---------- stop -----------"
$error.clear()
exit 0