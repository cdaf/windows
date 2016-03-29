$scriptName   = 'WIF.ps1'
$instalOption = 'runtimeonly or sdk' 
$version      = '4'
Write-Host
Write-Host "[$scriptName] Windows Identity Framework"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$version = $args[0]
if ($version) {
    Write-Host "[$scriptName] version  : $version"
} else {
	$version = '4'
    Write-Host "[$scriptName] version  : $version (default, choices $versionChoices)"
}

$instalOption = $args[1]
if ($instalOption) {
    Write-Host "[$scriptName] instalOption : $instalOption (options $instalOption)"
} else {
	$instalOption = 'runtimeonly'
    Write-Host "[$scriptName] instalOption : $instalOption (default, options $instalOption)"
}

$mediaDir = $args[2]
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = 'c:\vagrant\.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

switch ($version) {
	'4' {
		$file = 'Windows6.1-KB974405-x64.msu'
		$uri = 'https://download.microsoft.com/download/D/7/2/D72FD747-69B6-40B7-875B-C2B40A6B2BDD/' + $file
	}
    default {
	    Write-Host "[$scriptName] version not supported, choices are $versionChoices"
    }
}

Write-Host
$file = 'Windows6.1-KB974405-x64.msu'
$uri = 'https://download.microsoft.com/download/D/7/2/D72FD747-69B6-40B7-875B-C2B40A6B2BDD/' + $file
$fullpath = $mediaDir + '\' + $file
if ( Test-Path $fullpath ) {
	Write-Host "[$scriptName] $fullpath exists, download not required"
} else {

	$webclient = new-object system.net.webclient
	Write-Host "[$scriptName] $webclient.DownloadFile($uri, $fullpath)"
	$webclient.DownloadFile($uri, $fullpath)
}

try {
	$argList = @("$fullpath", '/quiet', '/norestart')
	Write-Host "[$scriptName] Start-Process -FilePath `'wusa.exe`' -ArgumentList $argList -PassThru -wait -Verb RunAs"
	$proc = Start-Process -FilePath 'wusa.exe' -ArgumentList $argList -PassThru -wait -Verb RunAs
} catch {
	Write-Host "[$scriptName] PowerShell Install Exception : $_" -ForegroundColor Red
	exit 200
}

if ($instalOption -eq 'sdk' ) {
	switch ($version) {
		'4' {
			$file = 'WindowsIdentityFoundation-SDK-4.0.msi'
			$uri = 'https://download.microsoft.com/download/7/0/1/70118832-3749-4C75-B860-456FC0712870/' + $file
		}
		'3.5' {
			$file = 'WindowsIdentityFoundation-SDK-3.5.msi'
			$uri  = 'https://download.microsoft.com/download/7/0/1/70118832-3749-4C75-B860-456FC0712870/' + $file
		}
	    default {
		    Write-Host "[$scriptName] version not supported, choices are $versionChoices"
	    }
	}
	
	$installFile = $mediaDir + '\' + $file
	Write-Host "[$scriptName] installFile : $installFile"
	
	$logFile = $installDir = [Environment]::GetEnvironmentVariable('TEMP', 'user') + '\' + $file + '.log'
	Write-Host "[$scriptName] logFile     : $logFile"
	
	Write-Host
	$fullpath = $mediaDir + '\' + $file
	if ( Test-Path $fullpath ) {
		Write-Host "[$scriptName] $fullpath exists, download not required"
	} else {
		$webclient = new-object system.net.webclient
		Write-Host "[$scriptName] $webclient.DownloadFile($uri, $fullpath)"
		$webclient.DownloadFile($uri, $fullpath)
	}
	
	$argList = @(
		"/qn",
		"/l*",
		"$logFile",
		"/i",
		"$installFile"
	)
	
	Write-Host "[$scriptName] Start-Process -FilePath msiexec -ArgumentList $argList -PassThru -wait -Verb RunAs"
	try {
		$proc = Start-Process -FilePath msiexec -ArgumentList $argList -PassThru -wait -Verb RunAs
	} catch {
		Write-Host "[$scriptName] $media Install Exception : $_" -ForegroundColor Red
		exit 200
	}
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host