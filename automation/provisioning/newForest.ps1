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

# Create or reuse mount directory
function mountWim ($media, $wimIndex, $mountDir) {
	Write-Host "[$scriptName] Validate WIM source ${media}:${wimIndex} using Deployment Image Servicing and Management (DISM)"
	executeExpression "dism /get-wiminfo /wimfile:$media"
	Write-Host
	Write-Host "[$scriptName] Mount to $mountDir using Deployment Image Servicing and Management (DISM)"
	executeExpression "Dism /Mount-Image /ImageFile:$media /index:$wimIndex /MountDir:$mountDir /ReadOnly /Optimize /Quiet"
}

$scriptName = 'newForest.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
Write-Host
Write-Host "[$scriptName] New Active Directory Forest, requires Windows Server 2012 and above."
Write-Host
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
    Write-Host "[$scriptName] wimIndex : (not passed)"
}

if ((gwmi win32_computersystem).partofdomain -eq $true) {
	$currentDomain = $((gwmi win32_computersystem).domain)
	if ($forest -eq $currentDomain) {
	    write-host -fore Red "Host $(hostname) already a domain member of $currentDomain"
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
Write-Host "[$scriptName] Install Active Directory Domain Roles and Services using Deployment Image Servicing and Management (DISM)"
Write-Host
Write-Host "[$scriptName] Source not required for RSAT (Remote Server Administration Tools)"
Write-Host
$featureList = @('ServerManager-Core-RSAT', 'ServerManager-Core-RSAT-Role-Tools', 'RSAT-AD-Tools-Feature')
foreach ($feature in $featureList) {
	executeExpression "dism /online /NoRestart /enable-feature /featurename:$feature /LimitAccess /Quiet"
}

Write-Host
Write-Host "[$scriptName] Source required for Directory Services"
Write-Host
$featureList = @('ActiveDirectory-PowerShell', 'DirectoryServices-DomainController', 'RSAT-ADDS-Tools-Feature', 'DirectoryServices-DomainController-Tools', 'DNS-Server-Full-Role', 'DNS-Server-Tools', 'DirectoryServices-AdministrativeCenter')
foreach ($feature in $featureList) {
	executeExpression "dism /online /NoRestart /enable-feature /featurename:$feature $sourceOption"
}

if ( Test-Path "$defaultMount\windows" ) {
	Write-Host "[$scriptName] Dismount default mount path ($defaultMount)"
	executeExpression "Dism /Unmount-Image /MountDir:$defaultMount /Discard /Quiet"
}

Write-Host
Write-Host "[$scriptName] Create the new Forest and convert this host into the FSMO Domain Controller"
Write-Host
$securePassword = ConvertTo-SecureString $password -asplaintext -force
executeExpression "Install-ADDSForest -DomainName $forest -SafeModeAdministratorPassword `$securePassword -Force"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
