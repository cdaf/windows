# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	$LASTEXITCODE = 0
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if ( $LASTEXITCODE -ne 0 ) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

$scriptName = 'CDAF.ps1'
Write-Host
Write-Host "[$scriptName] Execute the Continous Delivery Automation Framework for the solution."
Write-Host "[$scriptName] This process is dependant on the solution being synchonised onto the"
Write-Host "[$scriptName] `"build server`" using Vagrant and VirtualBox, which maps the local workspace"
Write-Host "[$scriptName] at C:\vagrant. If this is not used, then the workspace must be passed."
Write-Host
Write-Host "[$scriptName] By default the emulation is performed using the local Vagrant user, however"
Write-Host "[$scriptName] alternate credentials can be passed and a remote PowerShell connection will"
Write-Host "[$scriptName] be attempted, connecting back to the `"build server`" via the localhost adapter."
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
Write-Host
$userName = $args[0]
if ($userName) {
    Write-Host "[$scriptName] userName  : $userName"
} else {
    Write-Host "[$scriptName] userName  : not supplied, use local"
}

$userPass = $args[1]
if ($userPass) {
    Write-Host "[$scriptName] userPass  : **********"
} else {
    Write-Host "[$scriptName] userPass  : not supplied, use local"
}

$workspace = $args[2]
if ($workspace) {
    Write-Host "[$scriptName] workspace : $workspace"
} else {
	$workspace = 'c:\vagrant'
    Write-Host "[$scriptName] workspace : $workspace (default)"
}

$OPT_ARG = $args[3]
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
	Invoke-Command -ComputerName localhost -Credential $cred -ScriptBlock $script
	
	Write-Host "[$scriptName] `$LASTEXITCODE = Invoke-Command -ComputerName localhost -Credential `$cred -ScriptBlock { [Environment]::GetEnvironmentVariable('PREVIOUS_EXIT_CODE', 'User')} "
	$LASTEXITCODE = Invoke-Command -ComputerName localhost -Credential $cred -ScriptBlock { [Environment]::GetEnvironmentVariable('PREVIOUS_EXIT_CODE', 'User')}
    if ( $LASTEXITCODE -ne 0 ) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }

} else {

	Write-Host "[$scriptName] Execute as $(whoami) using workspace ($workspace)"
	executeExpression "cd $workspace"
	executeExpression ".\automation\processor\cdEmulate.ps1 $OPT_ARG"
}

Write-Host "`n[$scriptName] ---------- stop -----------"
exit 0