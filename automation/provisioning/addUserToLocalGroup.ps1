Param (
	[string]$group,
	[string]$userName,
	[string]$domain
)

cmd /c "exit 0"
$Error.Clear()

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1112 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red ; $error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				$error
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName] `$error[] = $error"; exit 1113
		}
	}
}

$scriptName = 'addUserToLocalGroup.ps1'

Write-Host "`n[$scriptName] ---------- start ----------"
if ($group) {
    Write-Host "[$scriptName] group    : $group"
} else {
	$group = 'Remote Management Users'
    Write-Host "[$scriptName] group    : $group (default)"
}

if ($userName) {
    Write-Host "[$scriptName] userName : $userName"
} else {
	$userName = 'Deployer'
    Write-Host "[$scriptName] userName : $userName (default)"
}

if ($domain) {
    Write-Host "[$scriptName] domain   : $domain"
} else {
    Write-Host "[$scriptName] domain   : not supplied, will treat as local machine (workgroup)"
}

if ($domain) {
	Write-Host
	Write-Host "[$scriptName] Add $domain/$userName to local group $group."
	$de = executeExpression "[ADSI]`"WinNT://$env:computername/$group,group`""
	executeExpression "`$de.psbase.Invoke(`"Add`",([ADSI]`"WinNT://$domain/$userName`").path)"
} else {
	if ( $userName.StartsWith('.\')) { 
		$userName = $userName.Substring(2) # Remove the .\ prefix
	}
	Write-Host "[$scriptName] Add $userName to local group $group."
	$argList = "localgroup `"$group`" $userName /add"
	Write-Host "[$scriptName] Start-Process net -ArgumentList $argList -PassThru -Wait"
	$proc = Start-Process net -ArgumentList $argList -PassThru -Wait
	if ( $proc.ExitCode -ne 0 ) {
		Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
	    exit $proc.ExitCode
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------"
