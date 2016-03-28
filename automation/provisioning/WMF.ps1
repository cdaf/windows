$scriptName     = 'WMF.ps1'
$versionChoices = '3 or 4' 
Write-Host
Write-Host "[$scriptName] Windows Management Framework (includes PowerShell)"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$version = $args[0]
if ($version) {
    Write-Host "[$scriptName] version  : $version"
} else {
	$version = '4'
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
	4 {
		$file = 'Windows6.1-KB2819745-x64-MultiPkg.msu'
		$uri = 'https://download.microsoft.com/download/3/D/6/3D61D262-8549-4769-A660-230B67E15B25/' + $file
	}
	3 {
		$file = 'Windows6.1-KB2506143-x64.msu'
		$uri = 'https://download.microsoft.com/download/E/7/6/E76850B8-DA6E-4FF5-8CCE-A24FC513FD16/' + $file
	}
    default {
	    Write-Host "[$scriptName] version not supported, choices are $versionChoices"
    }
}

$fullpath = $mediaDir + '\' + $file
if ( Test-Path $fullpath ) {
	Write-Host "[$scriptName] $fullpath exists, download not required"
} else {

	$webclient = new-object system.net.webclient
	Write-Host "[$scriptName] $webclient.DownloadFile($uri, $fullpath)"
	$webclient.DownloadFile($uri, $fullpath)
}
Write-Host
Write-Host "[$scriptName] List the PowerShell current version"
$PSVersionTable.PSVersion.Major
Write-Host

try {
	$argList = @("$fullpath", '/quiet', '/norestart')
	Write-Host "[$scriptName] Start-Process -FilePath `'wusa.exe`' -ArgumentList $argList -PassThru -wait"
	$proc = Start-Process -FilePath 'wusa.exe' -ArgumentList $argList -PassThru -wait
} catch {
	Write-Host "[$scriptName] PowerShell Install Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] List the PowerShell version after update"
$PSVersionTable.PSVersion.Major
Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host