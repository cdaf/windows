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
} else {
	$media = 'C:\.provision\install.wim'
    Write-Host "[$scriptName] media    : $media (default)"
}

$wimIndex = $args[3]
if ($wimIndex) {
    Write-Host "[$scriptName] wimIndex : $wimIndex"
} else {
	$wimIndex = '2'
    Write-Host "[$scriptName] wimIndex : $wimIndex (default, Standard Edition)"
}

if ( Test-Path $media ) {
	if ( $media -match ':' ) {
		$sourceOption = '-Source wim:' + $media + ":$wimIndex"
		Write-Host "[$scriptName] Media path found, using source option $sourceOption"
	} else {
		$sourceOption = '-Source ' + $media
		Write-Host "[$scriptName] Media path found, using source option $sourceOption"
	}
} else {
    Write-Host "[$scriptName] media path not found, will attempt to download from windows update."
}

Write-Host
Write-Host "[$scriptName] Install Active Directory Domain Roles and Services"
executeExpression "Install-WindowsFeature -Name `'AD-Domain-Services`' $sourceOption"

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
