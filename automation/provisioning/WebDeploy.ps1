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
		Write-Host; Write-Host "[$scriptName] Expression threw exxception. Exit with code 2, exception message follows ..."; Write-Host 
		Write-Host "[$scriptName] $_"; Write-Host 
		exit 2
	}
}

$scriptName = 'WebDeploy.ps1'
$versionChoices = '2 or 3.5' 
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$Installtype = $args[0]
if ($Installtype) {
    Write-Host "[$scriptName] Installtype : $Installtype"
} else {
	$Installtype = 'build'
    Write-Host "[$scriptName] Installtype : $Installtype (default, choices agent or build)"
}

$version = $args[1]
if ($version) {
    Write-Host "[$scriptName] version     : $version"
} else {
	$version = '3.5'
    Write-Host "[$scriptName] version     : $version (default, choices $versionChoices)"
}

$mediaDir = $args[2]
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir    : $mediaDir"
} else {
	$mediaDir = 'C:\vagrant\.provision'
    Write-Host "[$scriptName] mediaDir    : $mediaDir (default)"
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

$interactive = $args[3]
if ($interactive) {
    Write-Host "[$scriptName] interactive : $interactive, run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
} else {
    $sessionControl = '-PassThru -Wait'
}

switch ($version) {
	'3.5' {
		$file = 'WebDeploy_amd64_en-US.msi'
		$uri = 'http://download.microsoft.com/download/D/4/4/D446D154-2232-49A1-9D64-F5A9429913A4/' + $file
	}
	'2' {
		$file = 'WebDeploy_2_10_amd64_en-US.msi'
		$uri = 'http://download.microsoft.com/download/8/9/B/89B754A5-56F7-45BD-B074-8974FD2039AF/' + $file
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

# Output File (plain text or XML depending on method) must be supplioed
if ($Installtype -eq 'agent') {

    Write-Host "[$scriptName] For Installtype $Installtype, bind listener with default setting"
	$argList = @(
		"/qn",
		"/L*V",
		"$logFile",
		"/i",
		"$installFile",
		"ADDLOCAL=ALL",
		"LISTENURL=http://+:80/MsDeployAgentService"
	)
} else {
	
    Write-Host "[$scriptName] For Installtype $Installtype, only deploy MSBuild targets"
	$argList = @(
		"/qn",
		"/L*V",
		"$logFile",
		"/i",
		"$installFile"
	)
}

executeExpression "`$process = Start-Process -FilePath `'msiexec`' -ArgumentList `'$argList`' $sessionControl"

switch ($version) {
	'3.5' {
		$installPath = '3'
	}
	'2' {
		$installPath = $version
	}
    default {
	    Write-Host "[$scriptName] version not supported, choices are $versionChoices"
    }
}
$key = "HKLM:\SOFTWARE\Microsoft\IIS Extensions\MSDeploy\$installPath"
$name = 'InstallPath'
$InstallPath = (Get-ItemProperty -Path $key -Name $name).$name

write-host "Set environment variable MSDeployPath to $InstallPath"
[Environment]::SetEnvironmentVariable('MSDeployPath', "$InstallPath", 'User')

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
