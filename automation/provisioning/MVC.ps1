function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
}

$scriptName = 'MVC.ps1'
$versionChoices = '3 or 4'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$version = $args[0]
if ($version) {
    Write-Host "[$scriptName] version     : $version"
} else {
	$version = '4'
    Write-Host "[$scriptName] version     : $version (default, choices $versionChoices)"
}

$mediaDir = $args[1]
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir    : $mediaDir"
} else {
	$mediaDir = 'C:\.provision'
    Write-Host "[$scriptName] mediaDir    : $mediaDir (default)"
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

# [Environment]::SetEnvironmentVariable('interactive', 'true')
if ($env:interactive) {
    Write-Host "[$scriptName] env:interactive : $env:interactive, run in current window"
    $sessionControl = '-PassThru -wait -NoNewWindow '
} else {
    $sessionControl = '-PassThru -wait -ArgumentList $/q'
}

switch ($version) {
	4 {
		$file = 'AspNetMVC4Setup.exe'
		$uri = 'https://download.microsoft.com/download/2/F/6/2F63CCD8-9288-4CC8-B58C-81D109F8F5A3/' + $file
	}
	3 {
		$file = 'AspNetMVC3Setup.exe'
		$uri = 'https://download.microsoft.com/download/3/4/A/34A8A203-BD4B-44A2-AF8B-CA2CFCB311CC/' + $file
	}
    default {
	    Write-Host "[$scriptName] version not supported, choices are $versionChoices"
	    exit 1
    }
}

$installFile = $mediaDir + '\' + $file
Write-Host "[$scriptName] installFile : $installFile"

Write-Host
if ( Test-Path $installFile ) {
	Write-Host "[$scriptName] $installFile exists, download not required"
} else {

	$webclient = new-object system.net.webclient
	Write-Host "[$scriptName] $webclient.DownloadFile($uri, $installFile)"
	$webclient.DownloadFile($uri, $installFile)
}

executeExpression "Start-Process -FilePath $installFile $sessionControl"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
