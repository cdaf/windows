Param (
  [string]$mediaDirectory,
  [string]$url,
  [string]$pat,
  [string]$pool,
  [string]$agentName,
  [string]$serviceAccount,
  [string]$servicePassword
)
$scriptName = 'installAgent.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	$lastExitCode = 0
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if ( $lastExitCode -ne 0 ) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode "; exit $lastExitCode }
}

Write-Host "[$scriptName] ---------- start ----------"
if ( $mediaDirectory ) {
	Write-Host "[$scriptName] mediaDirectory  : $mediaDirectory"
} else {
	$mediaDirectory = 'C:\.provision'
	Write-Host "[$scriptName] mediaDirectory  : $mediaDirectory (default)"
}
if ( $url ) {
	Write-Host "[$scriptName] url             : $url"
} else {
	Write-Host "[$scriptName] url             : (not supplied)"
}
if ( $pat ) {
	Write-Host "[$scriptName] pat             : ***********************"
	if ( $pat -eq 'INVALID_VSTS_PAT_NOT_SET' ) {
		$provPAT = "-pat $pat" 
	} else {
		$provPAT = "-pat *******" 
	}	
} else {
	Write-Host "[$scriptName] pat             : (not supplied)"
}
if ( $pool ) {
	Write-Host "[$scriptName] pool            : $pool"
	$provPool = "-pool $pool" 
} else {
	Write-Host "[$scriptName] pool            : (not supplied)"
}
if ( $agentName ) {
	Write-Host "[$scriptName] agentName       : $agentName"
	$provAgent = "-agentName $agentName" 
} else {
	Write-Host "[$scriptName] agentName       : (not supplied)"
}
if ( $serviceAccount ) {
	Write-Host "[$scriptName] serviceAccount  : $serviceAccount"
	$provServ = "-serviceAccount $serviceAccount" 
} else {
	Write-Host "[$scriptName] serviceAccount  : (not supplied)"
}
if ( $servicePassword ) {
	Write-Host "[$scriptName] servicePassword : ******************************"
	$provPass = "-servicePassword ******" 
} else {
	Write-Host "[$scriptName] servicePassword : (not supplied)"
}
# Provisioning Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $mediaDirectory $url $provPAT $provPool $provAgent $provServ $provPass`""
}

executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'

$files = Get-ChildItem "$mediaDirectory/vsts-*"
if ($files) {
	Write-Host;	Write-Host "[$scriptName] Files available ..."
	foreach ($file in $files) {
		Write-Host "[$scriptName]   $($file.name)"
		$mediaFileName = $($file.name)
	}
	Write-Host; Write-Host "[$scriptName] Using latest file ($mediaFileName)"
} else {
	Write-Host "[$scriptName] mediaFileName with prefix `'vsts-`' not found, exiting with error code 1"; exit 1
}


Write-Host "`nExtract using default instructions from Microsoft"
if (Test-Path "C:\agent") {
	executeExpression "Remove-Item `"C:\agent`" -Recurse -Force"
}
executeExpression "mkdir C:\agent"
executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory(`"$mediaDirectory\$mediaFileName`", `"C:\agent`")"

if ( $url ) {

	if ( $serviceAccount ) {
	
		Write-Host "`nUnattend configuration for VSTS with PAT authentication"
		executeExpression "cd C:\agent"
		executeExpression ".\config.cmd --unattended --url $url --auth PAT --token `$pat --pool $pool --agent $agentName --replace --runasservice --windowslogonaccount $serviceAccount --windowslogonpassword `$servicePassword"
 
	} else {

		Write-Host "`nUnattend configuration for VSTS with PAT authentication"
		executeExpression "cd C:\agent"
		executeExpression ".\config.cmd --unattended --url $url --auth PAT --token `$pat --pool $pool --agent $agentName --replace"
	} 
}

Write-Host "`n[$scriptName] ---------- stop -----------`n"
exit 0