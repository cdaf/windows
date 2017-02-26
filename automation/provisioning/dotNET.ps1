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

$scriptName = 'dotNET.ps1'
$versionChoices = '4.6.1, 4.5.2, 4.5.1, 4.0 or 3.5' 
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$version = $args[0]
if (($version) -and ($version -ne 'latest')) {
    Write-Host "[$scriptName] version  : $version"
} else {
	$version = '4.6.1'
    Write-Host "[$scriptName] version  : $version (default, choices $versionChoices)"
}

$media = $args[1]
if ($media) {
    Write-Host "[$scriptName] media    : $media"
} else {
    Write-Host "[$scriptName] media    : not supplied"
}

$wimIndex = $args[2]
if ($wimIndex) {
    Write-Host "[$scriptName] wimIndex : $wimIndex"
} else {
    Write-Host "[$scriptName] wimIndex : (not supplied, use media directly)"
}

$mediaDir = $args[3]
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = '/.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

if ($env:interactive) {
	Write-Host
    Write-Host "[$scriptName]   env:interactive is set ($env:interactive), run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
	$logToConsole = 'true'
} else {
    $sessionControl = '-PassThru -Wait'
	$logToConsole = 'false'
}

Write-Host
switch ($version) {
	'4.6.1' {
		$file = 'NDP461-KB3102436-x86-x64-AllOS-ENU.exe'
		$uri = 'https://download.microsoft.com/download/E/4/1/E4173890-A24A-4936-9FC9-AF930FE3FA40/' + $file
	}
	'4.5.2' {
		$file = 'NDP452-KB2901907-x86-x64-AllOS-ENU.exe'
		$uri = 'https://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/' + $file
	}
	'4.5.1' {
		$file = 'NDP451-KB2858728-x86-x64-AllOS-ENU.exe'
		$uri = 'https://download.microsoft.com/download/1/6/7/167F0D79-9317-48AE-AEDB-17120579F8E2/' + $file
	}
	'4.0' {
		$file = 'dotNetFx40_Full_x86_x64.exe'
		$uri = 'https://download.microsoft.com/download/9/5/A/95A9616B-7A37-4AF6-BC36-D6EA96C8DAAE/' + $file
	}
	'3.5' {

		$defaultMount = 'C:\mountdir'
		
		Write-Host
		if ( $media ) {
			if ( Test-Path $media ) {
				Write-Host "[$scriptName] Media path ($media) found"
				if ($wimIndex) {
					Write-Host "[$scriptName] Index ($wimIndex) passed, treating media as Windows Imaging Format (WIM)"
					if ( Test-Path "$defaultMount" ) {
						if ( Test-Path "$defaultMount\windows" ) {
							Write-Host "[$scriptName] Default mount path found ($defaultMount\windows), assume already mounted, mount not attempted."
						} else {
							mountWim "$media" "$wimIndex" "$defaultMount"
						}
					} else {
						Write-Host "[$scriptName] Create default mount directory to $defaultMount"
						mkdir $defaultMount
						mountWim "$media" "$wimIndex" "$defaultMount"
					}
					$sourceOption = "/Source:$defaultMount\windows\WinSxS"
				} else {
					$sourceOption = "/Source:$media"
					Write-Host "[$scriptName] Media path found, using source option $sourceOption"
				}
				
				executeExpression "DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess $sourceOption"
			    if ( $lastExitCode -ne 0 ) {
					Write-Host "[$scriptName] Install failed, fallback to WSUS/Internet download"
					executeRetry "DISM /Online /Enable-Feature /FeatureName:NetFx3 /All"
				}
	
				if ( Test-Path "$defaultMount\windows" ) {
					Write-Host "[$scriptName] Dismount default mount path ($defaultMount)"
					executeExpression "Dism /Unmount-Image /MountDir:$defaultMount /Discard /Quiet"
				}
			} else {
				Write-Host "[$scriptName] Media passed but not found, attempt download from WSUS/Internet"
				executeRetry "DISM /Online /Enable-Feature /FeatureName:NetFx3 /All"
			}
		} else {
			Write-Host "[$scriptName] Media not passed, attempt download from WSUS/Internet"
			executeRetry "DISM /Online /Enable-Feature /FeatureName:NetFx3 /All"
		}
	}
    default {
	    Write-Host "[$scriptName] version not supported, choices are $versionChoices"
		exit 99
    }
}

# Not installed via DISM, attempt to install using offline file
if ($file) {

	$fullpath = $mediaDir + '\' + $file
	if ( Test-Path $fullpath -PathType Leaf) {
		Write-Host "[$scriptName] $fullpath exists, download not required"
	} else {
	
		$webclient = new-object system.net.webclient
		Write-Host "[$scriptName] $webclient.DownloadFile($uri, $fullpath)"
		try {
			$webclient.DownloadFile($uri, $fullpath)
		    	if(!$?) { exit 1 }
		} catch { echo $_.Exception|format-list -force; exit 2 }
	}
	
	try {
		$argList = @("/q", "/norestart")
		Write-Host "[$scriptName] Start-Process -FilePath $fullpath -ArgumentList $argList -PassThru -Wait"
		$proc = Start-Process -FilePath $fullpath -ArgumentList $argList -PassThru -Wait
	} catch {
		Write-Host "[$scriptName] .NET Install Exception : $_" -ForegroundColor Red
		exit 201
	}
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host