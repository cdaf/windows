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

$scriptName     = 'WMF.ps1'
$versionChoices = '3, 4 or 5' 
Write-Host
Write-Host "[$scriptName] --------------------------------------------------"
Write-Host "[$scriptName] Windows Management Framework (includes PowerShell)"
Write-Host "[$scriptName] --------------------------------------------------"
$version = $args[0]
if ($version) {
    Write-Host "[$scriptName] version  : $version"
} else {
	$version = '5'
    Write-Host "[$scriptName] version  : $version (default, choices $versionChoices)"
}

$mediaDir = $args[1]
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = 'C:\vagrant\.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

Write-Host

switch ($version) {
	'5' {
		$file = 'Win8.1AndW2K12R2-KB3134758-x64.msu'
		$uri = 'https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB/' + $file
	}
	'4' {
		$file = 'Windows6.1-KB2819745-x64-MultiPkg.msu'
		$uri = 'https://download.microsoft.com/download/3/D/6/3D61D262-8549-4769-A660-230B67E15B25/' + $file
	}
	'3' {
		$file = 'Windows6.1-KB2506143-x64.msu'
		$uri = 'https://download.microsoft.com/download/E/7/6/E76850B8-DA6E-4FF5-8CCE-A24FC513FD16/' + $file
	}
    default {
	    Write-Host "[$scriptName] version not supported, choices are $versionChoices"
    }
}

# Cannot run interactive via remote PowerShell
if ($env:interactive) {
    Write-Host "[$scriptName] env:interactive : $env:interactive, run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
} else {
    $sessionControl = '-PassThru -Wait'
}

Write-Host
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
	executeExpression "`$proc = Start-Process -FilePath `'wusa.exe`' -ArgumentList `'$argList`' $sessionControl"
} catch {
	Write-Host "[$scriptName] PowerShell Install Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host