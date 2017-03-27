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

function executeRetry ($expression) {
	$exitCode = 1
	$wait = 10
	$retryMax = 10
	$retryCount = 0
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "[$scriptName][$retryCount] $expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
		} catch { echo $_.Exception|format-list -force; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; $exitCode = 3 }
		if ( $LASTEXITCODE -eq 3010 ) { $LASTEXITCODE = 0 } # 3010 is a normal exit
	    if ( $lastExitCode -ne 0 ) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode "; $exitCode = $lastExitCode }
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with code $exitCode"; exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
				sleep $wait
			}
		}
    }
}

# Create or reuse mount directory
function mountWim ($media, $wimIndex, $mountDir) {
	Write-Host "[$scriptName] Validate WIM source ${media}:${wimIndex} using Deployment Image Servicing and Management (DISM)"
	executeExpression "dism /get-wiminfo /wimfile:$media"
	Write-Host
	Write-Host "[$scriptName] Mount to $mountDir using Deployment Image Servicing and Management (DISM)"
	executeExpression "Dism /Mount-Image /ImageFile:$media /index:$wimIndex /MountDir:$mountDir /ReadOnly /Optimize /Quiet"
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

# Cannot run interactive via remote PowerShell
if ($env:interactive) {
    Write-Host "[$scriptName] env:interactive : $env:interactive, run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
} else {
    $sessionControl = '-PassThru -Wait'
}

if ((gwmi win32_computersystem).partofdomain -eq $true) {
	$currentDomain = $((gwmi win32_computersystem).domain)
	if ($forest -eq $currentDomain) {
	    Write-Host
	    write-host "Host $(hostname) verified domain member of $currentDomain"
	    write-host "This is normal in Vagrant run after reboot for the provisioner to re-run."
	    Write-Host
		Write-Host "[$scriptName] ---------- stop ----------"
		exit 0
	} else {
	    write-host -fore Red "Host $(hostname) already a domain member of a different domain $currentDomain"
		exit 99
	}
}

$defaultMount = 'C:\mountdir'

Write-Host
if ( Test-Path $media ) {
	Write-Host "[$scriptName] Media path ($media) found"
	if ($wimIndex) {
		Write-Host "[$scriptName] Index ($wimIndex) passed, treating media as Windows Imaging Format (WIM)"
		if ( Test-Path "$defaultMount" ) {
			if ( Test-Path "$defaultMount\windows" ) {
				Write-Host "[$scriptName] Default mount path found ($defaultMount\windows), found, mount not attempted."
			} else {
				mountWim "$media" "$wimIndex" '$defaultMount'
			}
		} else {
			Write-Host "[$scriptName] Create default mount directory to $defaultMount"
			mkdir $defaultMount
			mountWim "$media" "$wimIndex" '$defaultMount'
		}
		$sourceOption = "/Source:$defaultMount\windows /LimitAccess /Quiet"
	} else {
		$sourceOption = "/Source:$media /LimitAccess /Quiet"
		Write-Host "[$scriptName] Media path found, using source option $sourceOption"
	}
} else {
    Write-Host "[$scriptName] media path not found, will attempt to download from windows update."
}

# Not using powershell commandlets for provisioning as they do not support /LimitAccess

Write-Host
Write-Host "[$scriptName]   Source required for Directory Services"
Write-Host
$featureList = @('ActiveDirectory-PowerShell', 'DirectoryServices-DomainController', 'RSAT-ADDS-Tools-Feature', 'DirectoryServices-DomainController-Tools', 'DNS-Server-Full-Role', 'DNS-Server-Tools', 'DirectoryServices-AdministrativeCenter')
foreach ($feature in $featureList) {
	executeExpression "dism /online /NoRestart /enable-feature /featurename:$feature $sourceOption"
	if ( $lastExitCode -ne 0 ) {
		Write-Host "[$scriptName] DISM failed with `$lastExitCode = $lastExitCode, retry from WSUS/Internet"
		executeRetry "dism /online /NoRestart /enable-feature /featurename:$feature /Quiet"
	}
}

if ( Test-Path "$defaultMount\windows" ) {
	Write-Host "[$scriptName] Dismount default mount path ($defaultMount)"
	executeExpression "Dism /Unmount-Image /MountDir:$defaultMount /Discard /Quiet"
}

# https://github.com/rgl/windows-domain-controller-vagrant/blob/master/provision/domain-controller.ps1
#   If using -NoRebootOnCompletion do not use reload module in Vagrant or it will fail (raise_if_auth_error)

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
