function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
}

$scriptName = 'doubleHopSPN.ps1'
Write-Host
Write-Host "Configure SPN for double hop authentication. Perform on Domain Controller."
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$spn = $args[0]
if ($spn) {
    Write-Host "[$scriptName] spn          : $spn"
} else {
	$spn = 'MSSQLSvc/DB:1433'
    Write-Host "[$scriptName] spn          : $spn (default)"
}

$user = $args[1]
if ($user) {
    Write-Host "[$scriptName] user         : $user"
} else {
	$user = 'deployer'
    Write-Host "[$scriptName] user         : $user (default)"
}

$host = $args[2]
if ($host) {
    Write-Host "[$scriptName] host         : $host"
} else {
	$host = 'APP'
    Write-Host "[$scriptName] host         : $host (default)"
}

executeExpression ".\setspn.exe -a $spn SKY\SQLSA"
executeExpression "Set-ADUser -Identity $user -TrustedForDelegation $True"
executeExpression "Set-ADComputer -Identity $host -TrustedForDelegation $True"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
