# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
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

	$securePassword = ConvertTo-SecureString $userPass -asplaintext -force
	$cred = New-Object System.Management.Automation.PSCredential ($userName, $securePassword)

	Write-Host "[$scriptName] Execute as $userName using workspace ($workspace)"
	executeExpression "Invoke-Command -ComputerName localhost -Credential `$cred -ScriptBlock { cd $workspace; .\automation\cdEmulate.bat $OPT_ARG }"
	executeExpression "Invoke-Command -ComputerName localhost -Credential `$cred -ScriptBlock { cd $workspace; .\automation\cdEmulate.bat clean }"

} else {

	Write-Host "[$scriptName] Execute as $(whoami) using workspace ($workspace)"
	executeExpression "cd $workspace"
	executeExpression ".\automation\processor\cdEmulate.ps1 $OPT_ARG"
	executeExpression ".\automation\processor\cdEmulate.ps1 clean"
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host