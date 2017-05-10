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

$scriptName = 'addUserToLocalGroup.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$group = $args[0]
if ($group) {
    Write-Host "[$scriptName] group    : $group"
} else {
	$group = 'Remote Management Users'
    Write-Host "[$scriptName] group    : $group (default)"
}

$userName = $args[1]
if ($userName) {
    Write-Host "[$scriptName] userName : $userName"
} else {
	$userName = 'Deployer'
    Write-Host "[$scriptName] userName : $userName (default)"
}

$domain = $args[2]
if ($domain) {
    Write-Host "[$scriptName] domain   : $domain"
} else {
    Write-Host "[$scriptName] domain   : not supplied, will treat as local machine (workgroup)"
}

# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $group $userName $domain`""
}

if ($domain) {
	Write-Host
	Write-Host "[$scriptName] Add $domain/$userName to local group $group."
	$de = executeExpression "[ADSI]`"WinNT://$env:computername/$group,group`""
	executeExpression "`$de.psbase.Invoke(`"Add`",([ADSI]`"WinNT://$domain/$userName`").path)"
} else {
	Write-Host "[$scriptName] Add .\$userName to local group $group."
	$argList = "localgroup `"$group`" $userName /add"
	Write-Host "[$scriptName] Start-Process net -ArgumentList $argList -PassThru -Wait"
	$proc = Start-Process net -ArgumentList $argList -PassThru -Wait
	if ( $proc.ExitCode -ne 0 ) {
		Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
	    exit $proc.ExitCode
	}
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
