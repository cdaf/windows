$scriptName = 'W2K8R2SP1.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$action = $args[0]
if ($action) {
    Write-Host "[$scriptName] action   : $action"
} else {
	$action = 'install'
    Write-Host "[$scriptName] action   : $action (default, choices install or verify)"
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

if ($action -eq "install") {
	Write-Host
	$file = 'windows6.1-KB976932-X64.exe'
	$fullpath = $mediaDir + '\' + $file
	if ( Test-Path $fullpath ) {
		Write-Host "[$scriptName] $fullpath exists, download not required"
	} else {
	
		$webclient = new-object system.net.webclient
		$uri = 'https://download.microsoft.com/download/0/A/F/0AFB5316-3062-494A-AB78-7FB0D4461357/' + $file
		Write-Host "[$scriptName] $webclient.DownloadFile($uri, $fullpath)"
		$webclient.DownloadFile($uri, $fullpath)
	}
}
	
Write-Host
Write-Host "[$scriptName] List the Computer architecture and Service Pack version"
$computer = "."
$sOS =Get-WmiObject -class Win32_OperatingSystem -computername $computer
foreach($sProperty in $sOS)
 {
    write-host "Caption                 : $($sProperty.Caption)"
    write-host "Description             : $($sProperty.Description)"
    write-host "OSArchitecture          : $($sProperty.OSArchitecture)"
    write-host "ServicePackMajorVersion : $($sProperty.ServicePackMajorVersion)"
 }
Write-Host

if ($action -eq "install") {
	try {
		$argList = @("/quiet", "/norestart")
		Write-Host "[$scriptName] Start-Process -FilePath $fullpath -ArgumentList $argList -PassThru -wait"
		$proc = Start-Process -FilePath $fullpath -ArgumentList $argList -PassThru -wait
	} catch {
		Write-Host "[$scriptName] PowerShell Install Exception : $_" -ForegroundColor Red
		exit 200
	}
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host

