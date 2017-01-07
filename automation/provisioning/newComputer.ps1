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
	$newName = "-newname $newComputerName"
} else {
	$newComputerName = "$(hostname)"
    Write-Host "[$scriptName] newComputerName : (not supplied, will add as $newComputerName)"
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

Write-Host "[$scriptName] Add this computer ($(hostname)) as $newComputerName to the domain"
executeExpression "Add-Computer -DomainName $forest -Passthru -Verbose -Credential `$cred $newName"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
