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

$scriptName = 'dotNET.ps1'
$versionChoices = '4.0, 4.5 or 3.5' 
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$version = $args[0]
if ($version) {
    Write-Host "[$scriptName] version  : $version"
} else {
	$version = '4.5'
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
	'4.5' {
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
				$online = "-Name NET-Framework-Features -Source $source"
				executeExpression "`$proc = Start-Process $sessionControl -FilePath 'Install-WindowsFeature' -ArgumentList $online"
			}
		}
		
		$file = 'dotnetfx35.exe'
		$uri = 'https://download.microsoft.com/download/2/0/E/20E90413-712F-438C-988E-FDAA79A8AC3D/' + $file
	}
    default {
	    Write-Host "[$scriptName] version not supported, choices are $versionChoices"
    }
}

if (!($online)) {

	$fullpath = $mediaDir + '\' + $file
	if ( Test-Path $fullpath ) {
		Write-Host "[$scriptName] $fullpath exists, download not required"
	} else {
	
		$webclient = new-object system.net.webclient
		Write-Host "[$scriptName] $webclient.DownloadFile($uri, $fullpath)"
		$webclient.DownloadFile($uri, $fullpath)
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