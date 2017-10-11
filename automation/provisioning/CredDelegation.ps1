# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

$scriptName = 'CredDelegation.ps1'
Write-Host
Write-Host "Applies Windows Domain : Allow a user or computer to delegate, i.e. `"double hop`""
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$identity = $args[0]
if ($identity) {
    Write-Host "[$scriptName] identity : $identity"
} else {
	$identity = 'deployer'
    Write-Host "[$scriptName] identity : $identity (default)"
}

$entity = $args[1]
if ($entity) {
    Write-Host "[$scriptName] entity   : $entity (choices user or computer)"
} else {
	$entity = 'user'
    Write-Host "[$scriptName] entity   : $entity (default, choices user or computer)"
}

if ($entity -eq 'user') {
	executeExpression "Set-ADUser -Identity $identity -TrustedForDelegation `$True"
} else {
	executeExpression "Set-ADComputer -Identity $passthruHost -TrustedForDelegation `$True"
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
