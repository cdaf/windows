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

$scriptName = 'newDC.ps1'
Write-Host
Write-Host "[$scriptName] New Domain Controller to existing Forest, Windows Server 2012 and above"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$forest = $args[0]
if ($forest) {
    Write-Host "[$scriptName] forest : $forest"
} else {
	$forest = 'sky.net'
    Write-Host "[$scriptName] forest : $forest (default)"
}

$password = $args[1]
if ($password) {
    Write-Host "[$scriptName] password : ********** "
} else {
	$password = 'Puwreyu5Asegucacr6za'
    Write-Host "[$scriptName] password : ********** (default)"
}

$media = $args[2]
if ($media) {
    Write-Host "[$scriptName] media    : $media"
	$source = '-Source ' + $media
} else {
	$defaultSource = 'C:\vagrant\.provision\sxs'
	if ( Test-Path $defaultSource ) {
		Write-Host "[$scriptName] Default media path found, using $defaultSource"
		$source = '-Source ' + $defaultSource
	} else {
	    Write-Host "[$scriptName] media not supplied, will attempt to download from windows update."
	}
}

Write-Host
Write-Host "[$scriptName] Install Active Directory Domain Roles and Services"
executeExpression "Install-WindowsFeature -Name `'AD-Domain-Services`' $source"

$securePassword = ConvertTo-SecureString $password -asplaintext -force

# Diagnostic helpers
# Test-ADDSForestInstallation -DomainName $forest -SafeModeAdministratorPassword $securePassword
# Test-ADDSDomainInstallation -NewDomainName $forest -ParentDomainName 'sky.net' -SafeModeAdministratorPassword $securePassword
# Test-ADDSDomainControllerInstallation -DomainName $forest -SafeModeAdministratorPassword $securePassword

Write-Host "[$scriptName] Convert this host into a member domain controller in the forest"
Import-Module ADDSDeployment
Install-ADDSDomainController `
	-NoGlobalCatalog:$false `
	-InstallDns:$false `
	-CreateDnsDelegation:$false `
	-CriticalReplicationOnly:$false `
	-DatabasePath "C:\Windows\NTDS" `
	-LogPath "C:\Windows\NTDS" `
	-SysvolPath "C:\Windows\SYSVOL" `
	-DomainName $forest `
	-NoRebootOnCompletion:$false `
	-SiteName 'vagrant' `
	-Force:$true `
	-SafeModeAdministratorPassword $securePassword

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
