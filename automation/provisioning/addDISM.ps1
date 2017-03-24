# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
	if ( $LASTEXITCODE -eq 3010 ) { $LASTEXITCODE = 0 } # 3010 is a normal exit
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

# Not using powershell commandlets for provisioning as they do not support /LimitAccess
# $featureList = @('ActiveDirectory-PowerShell', 'DirectoryServices-DomainController', 'RSAT-ADDS-Tools-Feature', 'DirectoryServices-DomainController-Tools', 'DNS-Server-Full-Role', 'DNS-Server-Tools', 'DirectoryServices-AdministrativeCenter')
$scriptName = 'newDISM.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
Write-Host
$featureList= $args[0]
if ($featureList) {
    Write-Host "[$scriptName] featureList   : $featureList"
} else {
    Write-Host "[$scriptName] ERROR: List of Features not passed, halting with LASTEXITCODE=1"; exit 1
}

$media = $args[1]
if ($media) {
    Write-Host "[$scriptName] media         : $media"
} else {
    Write-Host "[$scriptName] media         : (not passed)"
}

$wimIndex = $args[2]
if ($wimIndex) {
    Write-Host "[$scriptName] wimIndex      : $wimIndex"
} else {
    Write-Host "[$scriptName] wimIndex      : (not passed)"
}

# Cannot run interactive via remote PowerShell
if ($env:interactive) {
    Write-Host "[$scriptName] env:interactive : $env:interactive, run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
} else {
    $sessionControl = '-PassThru -Wait'
}

$defaultMount = 'C:\mountdir'
$sourceOption = '/Quiet'

Write-Host
if ( $media ) {
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
}

Write-Host
$featureArray = $featureList.split(" ")
foreach ($feature in $featureArray) {
	if ( $sourceOption -eq '/Quiet' ) {
		executeRetry "dism /online /NoRestart /enable-feature /featurename:$feature $sourceOption"
	} else {
		executeExpression "dism /online /NoRestart /enable-feature /featurename:$feature $sourceOption"
		if ( $lastExitCode -ne 0 ) {
			Write-Host "[$scriptName] DISM failed with `$lastExitCode = $lastExitCode, retry from WSUS/Internet"
			executeRetry "dism /online /NoRestart /enable-feature /All /featurename:$feature /Quiet"
		}
	}
}

if ( Test-Path "$defaultMount\windows" ) {
	Write-Host "[$scriptName] Dismount default mount path ($defaultMount)"
	executeExpression "Dism /Unmount-Image /MountDir:$defaultMount /Discard /Quiet"
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
