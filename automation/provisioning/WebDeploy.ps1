$scriptName     = 'WebDeploy.ps1'
$versionChoices = '2 or 3' 
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
	$version = '3'
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

switch ($version) {
	3 {
		$file = 'WebDeploy_amd64_en-US.msi'
		$uri = 'https://download.microsoft.com/download/1/B/3/1B3F8377-CFE1-4B40-8402-AE1FC6A0A8C3/' + $file
	}
	2 {
		$file = 'WebDeploy_2_10_amd64_en-US.msi'
		$uri = 'https://download.microsoft.com/download/8/9/B/89B754A5-56F7-45BD-B074-8974FD2039AF/' + $file
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
    Write-Host "[$scriptName] For Installtype $Installtype, provisioning IIS"
    
	# Enable IIS features before installing Web Deploy
	try {
		Write-Host "[$scriptName] Start-Process -FilePath `'dism`' -ArgumentList `'/online /enable-feature /featurename:IIS-WebServerRole /featurename:IIS-WebServerManagementTools /featurename:IIS-ManagementService`' -PassThru -wait -Verb RunAs"
		$proc = Start-Process -FilePath 'dism' -ArgumentList '/online /enable-feature /featurename:IIS-WebServerRole /featurename:IIS-WebServerManagementTools /featurename:IIS-ManagementService' -PassThru -wait -Verb RunAs
		  
		Write-Host "[$scriptName] Start-Process -FilePath `'Reg`' -ArgumentList `'Add HKLM\Software\Microsoft\WebManagement\Server /V EnableRemoteManagement /T REG_DWORD /D 1 /f`' -PassThru -wait -Verb RunAs"
		$proc = Start-Process -FilePath 'Reg' -ArgumentList 'Add HKLM\Software\Microsoft\WebManagement\Server /V EnableRemoteManagement /T REG_DWORD /D 1 /f' -PassThru -wait -Verb RunAs

		Write-Host "[$scriptName] Start-Process -FilePath `'net`' -ArgumentList `'start wmsvc`' -PassThru -wait"
		$proc = Start-Process -FilePath 'net' -ArgumentList 'start wmsvc' -PassThru -wait
	} catch {
		Write-Host "[$scriptName] $media Install Exception : $_" -ForegroundColor Red
		exit 200
	}
	
	$argList = @(
		"/qn",
		"/l*",
		"$logFile",
		"/i",
		"$installFile",
		"ADDLOCAL=ALL",
		"LISTENURL=http://+:8080/MsDeployAgentService2/"
	)
} else {
    Write-Host "[$scriptName] For Installtype $Installtype only deploy build targets"
	$argList = @(
		"/qn",
		"/l*",
		"$logFile",
		"/i",
		"$installFile"
	)
}

Write-Host "[$scriptName] Start-Process -FilePath `'msiexec`' -ArgumentList $argList -PassThru -wait -Verb RunAs"
try {
	$proc = Start-Process -FilePath 'msiexec' -ArgumentList $argList -PassThru -wait -Verb RunAs
} catch {
	Write-Host "[$scriptName] $media Install Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
