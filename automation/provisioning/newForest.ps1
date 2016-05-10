function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	# Execute expression and trap powershell exceptions
	try {
	    Invoke-Expression $expression
	    if(!$?) {
			Write-Host; Write-Host "[$scriptName] Expression failed without an exception thrown. Exit with code 1."; Write-Host 
			exit 1
		}
	} catch {
		Write-Host; Write-Host "[$scriptName] Expression threw exception. Exit with code 2, exception message follows ..."; Write-Host 
		Write-Host "[$scriptName] $_"; Write-Host 
		exit 2
	}
}

$scriptName = 'newForest.ps1'
Write-Host
Write-Host "[$scriptName] New Forest, Windows Server 2012 and above"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$forest = $args[0]
if ($forest) {
    Write-Host "[$scriptName] forest   : $forest"
} else {
	$forest = 'sky.net'
    Write-Host "[$scriptName] forest   : $forest (default)"
}

$password = $args[1]
if ($password) {
    Write-Host "[$scriptName] password : ********** "
} else {
	$password = 'Puwreyu5Asegucacr6za'
    Write-Host "[$scriptName] password : ********** (default)"
}

Write-Host
Write-Host "[$scriptName] Install the Active Directory Domain Services role"
executeExpression "Get-WindowsFeature AD-Domain-Services | Install-WindowsFeature"

Write-Host
Write-Host "[$scriptName] Install the Active Directory Domain Services role"
$securePassword = ConvertTo-SecureString $password -asplaintext -force
executeExpression "Install-ADDSForest -DomainName $forest -SafeModeAdministratorPassword `$securePassword -Force"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
