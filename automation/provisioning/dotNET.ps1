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

$mediaDir = $args[1]
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
				$online = 'DISM /Online /Enable-Feature /FeatureName:NetFx3 /Norestart'
				Write-Host $online
			}
		}
		$file = 'dotnetfx35.exe'
		$uri = 'https://download.microsoft.com/download/2/0/E/20E90413-712F-438C-988E-FDAA79A8AC3D/' + $file
	}
    default {
	    Write-Host "[$scriptName] version not supported, choices are $versionChoices"
    }
}

if ($online ) {

    # Execute expression and trap powershell exceptions
    try {
        Invoke-Expression $online
	} catch {
		Write-Host "[$scriptName] .NET 3.5 Install Exception : $_" -ForegroundColor Red
		exit 201
	}

} else {

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
		Write-Host "[$scriptName] Start-Process -FilePath $fullpath -ArgumentList $argList -PassThru -wait"
		$proc = Start-Process -FilePath $fullpath -ArgumentList $argList -PassThru -wait
	} catch {
		Write-Host "[$scriptName] .NET Install Exception : $_" -ForegroundColor Red
		exit 200
	}
}
Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host