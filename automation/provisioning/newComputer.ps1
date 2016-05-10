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

$scriptName = 'newComputer.ps1'
Write-Host
Write-Host "[$scriptName] New Computer on Domain, Windows Server 2012 and above"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$forest = $args[0]
if ($forest) {
    Write-Host "[$scriptName] forest          : $forest"
} else {
	$forest = 'sky.net'
    Write-Host "[$scriptName] forest          : $forest (default)"
}

$newComputerName = $args[1]
if ($newComputerName) {
    Write-Host "[$scriptName] newComputerName : $newComputerName"
	$newName = '-newname $newComputerName'
} else {
    Write-Host "[$scriptName] newComputerName : not supplied"
}

$domainAdminUser = $args[2]
if ($domainAdminUser) {
    Write-Host "[$scriptName] domainAdminUser : $domainAdminUser"
} else {
	$domainAdminUser = 'vagrant'
    Write-Host "[$scriptName] domainAdminUser : $domainAdminUser (default)"
}

$domainAdminPass = $args[3]
if ($domainAdminPass) {
    Write-Host "[$scriptName] domainAdminPass : **********"
} else {
	$domainAdminPass = 'vagrant'
    Write-Host "[$scriptName] domainAdminPass : ********** (default)"
}

$securePassword = ConvertTo-SecureString $domainAdminPass -asplaintext -force
$cred = New-Object System.Management.Automation.PSCredential ($domainAdminUser, $securePassword)

Write-Host "[$scriptName] Add this computer ($(hostname)) to the domain"
executeExpression "Add-Computer -DomainName $forest -Passthru -Verbose -Credential `$cred $newName"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
