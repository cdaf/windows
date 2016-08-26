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

$source = $args[1]
if ($source) {
    Write-Host "[$scriptName] source   : $source"
} else {
    Write-Host "[$scriptName] source   : not supplied"
}

$mediaDir = $args[2]
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = '/vagrant/.provision'
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
		$computer = "."
		$sOS =Get-WmiObject -class Win32_OperatingSystem -computername $computer
		foreach($sProperty in $sOS) {
			if ( $sProperty.Caption -match '2008' ) {
				Write-Host "[$scriptName] Cannot use installer on Win 7 or Server 2008, will try:"
				$online = '/Online /Enable-Feature /FeatureName:NetFx3 /Norestart'
				Write-Host "DISM $online"
				try {
					executeExpression "`$proc = Start-Process -FilePath 'DISM' -ArgumentList $online $sessionControl"
				} catch {
					Write-Host "[$scriptName] .NET 3.5 Install Exception : $_" -ForegroundColor Red
					exit 200
				}
			}
		}
		
		if (!($online)) {
			if ($source) {
				Write-Host "[$scriptName] Win 8.1 or Server 2012 or later, and source supplied, using Windows Server configuration"
				$online = "-Source $source"
				executeExpression "Install-WindowsFeature -Name `'NET-Framework-Features`' $online"
			}
		}
		
		$file = 'dotnetfx35.exe'
		$uri = 'https://download.microsoft.com/download/2/0/E/20E90413-712F-438C-988E-FDAA79A8AC3D/' + $file
	}
    default {
	    Write-Host "[$scriptName] version not supported, choices are $versionChoices"
		exit 99
    }
}

if (!($online)) {

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