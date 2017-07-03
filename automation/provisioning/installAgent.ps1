Param (
  [string]$url,
  [string]$pat,
  [string]$pool,
  [string]$agentName,
  [string]$serviceAccount,
  [string]$servicePassword,
  [string]$deploymentgroup,
  [string]$projectname,
  [string]$mediaDirectory
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
if ( $url ) {
	Write-Host "[$scriptName] url             : $url"
	$optParms += "-url `$url"
} else {
	Write-Host "[$scriptName] url             : (not supplied, will just extract the agent software)"
}
if ( $pat ) {
	Write-Host "[$scriptName] pat             : `$pat"
	$optParms += "-pat `$pat"
} else {
	Write-Host "[$scriptName] pat             : (not supplied)"
}
if ( $pool ) {
	Write-Host "[$scriptName] pool            : $pool"
} else {
	$pool = 'default'
	Write-Host "[$scriptName] pool            : $pool (not supplied, set to default, if Deployment Group is used, this will be ignored)"
}
$optParms += " -pool `$pool"
if ( $agentName ) {
	Write-Host "[$scriptName] agentName       : $agentName"
} else {
	$agentName = "$env:COMPUTERNAME" 
	Write-Host "[$scriptName] agentName       : $agentName (not supplied, set to default)"
}
$optParms += " -agentName `$agentName"
if ( $serviceAccount ) {
	Write-Host "[$scriptName] serviceAccount  : $serviceAccount"
	$optParms += " -serviceAccount $serviceAccount"
} else {
	Write-Host "[$scriptName] serviceAccount  : (not supplied)"
}
if ( $servicePassword ) {
	Write-Host "[$scriptName] servicePassword : `$servicePassword"
	$optParms += " -servicePassword `$password"
} else {
	Write-Host "[$scriptName] servicePassword : (not supplied)"
}
if ( $deploymentgroup ) {
	Write-Host "[$scriptName] deploymentgroup : $deploymentgroup"
	$optParms += " -deploymentgroup `$deploymentgroup"
} else {
	Write-Host "[$scriptName] deploymentgroup : (not supplied)"
}
if ( $projectname ) {
	Write-Host "[$scriptName] projectname     : $projectname"
	$optParms += " -projectname `$projectname"
} else {
	if ( $deploymentgroup ) {
		Write-Host "[$scriptName] deploymentgroup ($deploymentgroup) supplied, therefore projectname required but not supplied, exit with `$LASTEXITCODE = 3"; exit 3
	} else {
		Write-Host "[$scriptName] projectname     : (not supplied)"
	}
}
if ( $mediaDirectory ) {
	Write-Host "[$scriptName] mediaDirectory  : $mediaDirectory"
} else {
	$mediaDirectory = 'C:\.provision'
	Write-Host "[$scriptName] mediaDirectory  : $mediaDirectory (not supplied, set to default)"
}
$optParms += " -mediaDirectory $mediaDirectory"
# Provisioning Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $url $optParms `""
}
$fullpath = 'C:\agent\config.cmd'
$workspace = $(pwd)

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
	$argList = "--unattended --url $url --auth PAT"
	if ( $deploymentgroup ) {
		$argList += " --deploymentgroup --deploymentgroupname `"$deploymentgroup`" --projectname `"$projectname`""
	}
	
	Write-Host "`nUnattend configuration for VSTS with PAT authentication"
	if ( $serviceAccount ) {
		$printList = "$argList --token `$pat --pool $pool --agent $agentName --replace --runasservice --windowslogonaccount $serviceAccount --windowslogonpassword `$servicePassword"
		$argList += " --token $pat --pool $pool --agent $agentName --replace --runasservice --windowslogonaccount $serviceAccount --windowslogonpassword $servicePassword"
	} else {
		$printList = "$argList --token `$pat --pool $pool --agent $agentName --replace"
		$argList += " --token $pat --pool $pool --agent $agentName --replace"
	}
	
	executeExpression "cd C:\agent"
	Write-Host "[$scriptName] Start-Process $fullpath -ArgumentList $printList -PassThru -Wait"
	$proc = Start-Process $fullpath -ArgumentList $argList -PassThru -Wait
	if ( $proc.ExitCode -ne 0 ) {
		Write-Host "`n[$scriptName] Error occured, listing last 40 lines of log $((Get-ChildItem C:\agent\_diag)[0].FullName)`n"
		Get-Content (Get-ChildItem C:\agent\_diag)[0].FullName -tail 40
		Write-Host "`n[$scriptName] Install Failed! Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
	    exit $proc.ExitCode
	}
} else {
	Write-Host "`n[$scriptName] URL not supplied. Agent software extracted to C:\agent`n"
}

executeExpression "cd $workspace"
Write-Host "`n[$scriptName] ---------- stop -----------`n"
exit 0