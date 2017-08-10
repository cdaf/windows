Param (
  [string]$version,
  [string]$media,
  [string]$wimIndex,
  [string]$mediaDir,
  [string]$sdk,
  [string]$reboot
)
$scriptName = 'dotNET.ps1' # (no arguments)             | install latest .NET runtime
                           # 4.5.1 install.wim 2        | install 4.5.1 from Windows Image file, found on install media
                           # 4.6.1 -reboot yes          | install 4.6.1 and reboot when complete
                           # -sdk yes -reboot shutdown  | install latest, including devpack then shutdown
                           # -sdk force                 | force install, i.e. to replace runtime only installation
                           
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
	$retryMax = 3
	$retryCount = 0
	$exitCode = 1 # Any value other than 0 to enter the loop
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

# .NET 4.5 and above
function IsInstalled ($release) {
	Write-Host "`n[$scriptName] Target .NET Release is $release"
    $ver = executeExpression "(Get-ItemProperty -Path `'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full`').Release"
	Write-Host "`n[$scriptName] Current .NET Release is $ver"
    return (!($ver -eq $null) -and ($ver -ge $release))
}

function installFourAndAbove {
	$rebootRequired = $False
	$fullpath = $mediaDir + '\' + $file
	if ( Test-Path $fullpath -PathType Leaf) {
		Write-Host "`n[$scriptName] $fullpath exists, download not required"
	} else {
	
		$webclient = new-object system.net.webclient
		Write-Host "[$scriptName] $webclient.DownloadFile($uri, $fullpath)"
		try {
			$webclient.DownloadFile($uri, $fullpath)
		    	if(!$?) { exit 1 }
		} catch { echo $_.Exception|format-list -force; exit 2 }
	}
	
	try {
		if ($sdk -eq 'force') {
			$argList = @("/repair", "/q", "/norestart", "/log `"$env:temp\$file`"")
		} else {
			$argList = @("/q", "/norestart", "/log `"$env:temp\$file`"")
		}
		Write-Host "[$scriptName] Start-Process -FilePath $fullpath -ArgumentList $argList -PassThru -Wait"
		$proc = Start-Process -FilePath $fullpath -ArgumentList $argList -PassThru -Wait
        if ( $proc.ExitCode -ne 0 ) {
	        if ( $proc.ExitCode -eq 3010 ) {
	    		Write-Host "`n[$scriptName] Exit 3010, The requested operation is successful. Changes will not be effective until the system is rebooted.`n"
				$rebootRequired = $True
	        } else {
	    		Write-Host "`n[$scriptName] Install Failed, see log file ($env:temp\${file}.html) for details. Exit with `$LASTEXITCODE = $proc.ExitCode`n"  -ForegroundColor Red; exit $proc.ExitCode
			}
        }
	} catch {
		Write-Host "[$scriptName] .NET Install Exception : $_" -ForegroundColor Red; exit 201
	}
    return $rebootRequired
}

$scriptName = 'dotNET.ps1'
$latest = '4.7'
$versionChoices = "$latest, 4.6.2, 4.6.1, 4.5.2, 4.5.1, 4.0, 3.5 or latest"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
if ($version) {
	if ($version -eq 'latest') {
		$version = $latest
	    Write-Host "[$scriptName] version  : $version (latest)"
	} else {
	    Write-Host "[$scriptName] version  : $version"
    }
} else {
	$version = $latest
    Write-Host "[$scriptName] version  : $version (default to latest, choices $versionChoices)"
}

if ($media) {
    Write-Host "[$scriptName] media    : $media"
    $mediaRun = "-media $media"
} else {
    Write-Host "[$scriptName] media    : not supplied"
}

if ($wimIndex) {
    Write-Host "[$scriptName] wimIndex : $wimIndex"
    $indexRun = "-wimIndex $wimIndex"
} else {
    Write-Host "[$scriptName] wimIndex : (not supplied, use media directly)"
}

if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = 'C:\.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

if ($sdk) {
    Write-Host "[$scriptName] sdk      : $sdk (yes, no or force)"
} else {
	$sdk = 'no'
    Write-Host "[$scriptName] sdk      : $sdk (default, options are yes, no or force)"
}

if ($reboot) {
    Write-Host "[$scriptName] reboot   : $reboot (options yes, no or shutdown)"
} else {
	$reboot = 'no'
    Write-Host "[$scriptName] reboot   : $reboot (default, options yes, no or shutdown)"
}
# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $version $mediaRun $indexRun -mediaDir $mediaDir -sdk $sdk -reboot $reboot`""
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
	'4.7' {
		if ($sdk -ne 'no') {
			$file = 'NDP47-DevPack-KB3186612-ENU.exe'
			$uri = 'https://download.microsoft.com/download/A/1/D/A1D07600-6915-4CB8-A931-9A980EF47BB7/' + $file
		} else {
			$file = 'NDP47-KB3186497-x86-x64-AllOS-ENU.exe'
			$uri = 'http://download.microsoft.com/download/D/D/3/DD35CC25-6E9C-484B-A746-C5BE0C923290/' + $file
		}
		$release = '460798' # Lowest of 460798 (Win 10) and 460805 (all other OS)
	}
	'4.6.2' {
		if ($sdk -ne 'no') {
			$file = 'NDP462-DevPack-KB3151934-ENU.exe'
			$uri = 'https://download.microsoft.com/download/E/F/D/EFD52638-B804-4865-BB57-47F4B9C80269/' + $file
		} else {
			$file = 'NDP462-KB3151800-x86-x64-AllOS-ENU.exe'
			$uri = 'https://download.microsoft.com/download/F/9/4/F942F07D-F26F-4F30-B4E3-EBD54FABA377/' + $file
		}
		$release = '394802' # Lowest of 394802 (Win 10) and 394806 (all other OS)
	}
	'4.6.1' {
		if ($sdk -ne 'no') {
			$file = 'NDP461-DevPack-KB3105179-ENU.exe'
			$uri = 'https://download.microsoft.com/download/F/1/D/F1DEB8DB-D277-4EF9-9F48-3A65D4D8F965/' + $file
		} else {
			$file = 'NDP461-KB3102436-x86-x64-AllOS-ENU.exe'
			$uri = 'https://download.microsoft.com/download/E/4/1/E4173890-A24A-4936-9FC9-AF930FE3FA40/' + $file
		}
		$release = '394254'
	}
	'4.5.2' {
		if ($sdk -ne 'no') {
			$file = 'NDP452-KB2901951-x86-x64-DevPack.exe'
			$uri = 'https://download.microsoft.com/download/4/3/B/43B61315-B2CE-4F5B-9E32-34CCA07B2F0E/' + $file
		} else {
			$file = 'NDP452-KB2901907-x86-x64-AllOS-ENU.exe'
			$uri = 'https://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/' + $file
		}
		$release = '379893'
	}
	'4.5.1' {
		if ($sdk -ne 'no') {
			$file = 'NDP451-KB2861696-x86-x64-DevPack.exe'
			$uri = 'http://download.microsoft.com/download/9/6/0/96075294-6820-4F01-924A-474E0023E407/' + $file
		} else {
			$file = 'NDP451-KB2858728-x86-x64-AllOS-ENU.exe'
			$uri = 'https://download.microsoft.com/download/1/6/7/167F0D79-9317-48AE-AEDB-17120579F8E2/' + $file
		}
		$release = '378675' # Lowest of 378675 (Windows 8.1 or Windows Server 2012 R2) and 378758 (Windows 8, Windows 7 SP1, or Windows Vista SP2)
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

	if ($release) {
		if (IsInstalled $release) {
			if ($sdk -eq 'force') {
			    Write-Host "[$scriptName] Microsoft .NET Framework $version or later is already installed, however, forcing install of sdk"
				$rebootRequired = installFourAndAbove # .NET 4.5 and above
		    } else {
			    Write-Host "[$scriptName] Microsoft .NET Framework $version or later is already installed"
		    }
		} else {
			$rebootRequired = installFourAndAbove # .NET 4.5 and above
		}
	} else {
		$rebootRequired = installFourAndAbove # .NET 4
	}

	if ( $rebootRequired ) {
		switch ($reboot) {
			'yes' {
		        Write-Host "`n[$scriptName] Reboot in 1 second and return `$LASTEXITCODE = 3010"
		        executeExpression "shutdown /r /t 1"
		        exit 3010
	        }
			'shutdown' {
		        Write-Host "`n[$scriptName] Shutdown in 1 second and return `$LASTEXITCODE = 3010"
		        executeExpression "shutdown /s /t 1"
		        exit 3010
	        }
	        default {
		        Write-Host "`n[$scriptName] Reboot is required, but reboot set to ${reboot}, so shutdown action not attempted and returning `$LASTEXITCODE = 0"
	        }
        }
    }
}

Write-Host "`n[$scriptName] ---------- stop -----------`n"
exit 0