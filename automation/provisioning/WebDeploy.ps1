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

$scriptName = 'WebDeploy.ps1'
$versionChoices = '2 or 3.5' 
Write-Host
Write-Host "[$scriptName] Install Web Deploy. As of Visual Studio 2015 Web Deploy build targets are automatically"
Write-Host "[$scriptName] included, so the default action for this provisioner is now agent."
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$Installtype = $args[0]
if ($Installtype) {
    Write-Host "[$scriptName] Installtype     : $Installtype"
} else {
	$Installtype = 'agent'
    Write-Host "[$scriptName] Installtype     : $Installtype (default, choices agent or build)"
}

$MsDepSvcPort = $args[1]
if ($MsDepSvcPort) {
    Write-Host "[$scriptName] MsDepSvcPort    : $MsDepSvcPort"
} else {
	$MsDepSvcPort = '80'
    Write-Host "[$scriptName] MsDepSvcPort    : $MsDepSvcPort (default)"
}

$version = $args[2]
if ($version) {
    Write-Host "[$scriptName] version         : $version"
} else {
	$version = '3.5'
    Write-Host "[$scriptName] version         : $version (default, choices $versionChoices)"
}

$mediaDir = $args[3]
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir        : $mediaDir"
} else {
	$mediaDir = 'C:\.provision'
    Write-Host "[$scriptName] mediaDir        : $mediaDir (default)"
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

if ($env:interactive) {
    Write-Host "[$scriptName] env:interactive : $env:interactive, run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
} else {
    $sessionControl = '-PassThru -Wait'
}

# Install path is used for reading from registry after install is complete
switch ($version) {
	'3.5' {
		$installPath = '3'
		$file = 'WebDeploy_amd64_en-US.msi'
		$uri = 'http://download.microsoft.com/download/D/4/4/D446D154-2232-49A1-9D64-F5A9429913A4/' + $file
	}
	'2' {
		$installPath = $version
		$file = 'WebDeploy_2_10_amd64_en-US.msi'
		$uri = 'http://download.microsoft.com/download/8/9/B/89B754A5-56F7-45BD-B074-8974FD2039AF/' + $file
	}
    default {
	    Write-Host "[$scriptName] version not supported, choices are $versionChoices"
    }
}

# Prepare Install Media
$installFile = $mediaDir + '\' + $file
Write-Host "[$scriptName] installFile     : $installFile"

$logFile = $installDir = [Environment]::GetEnvironmentVariable('TEMP', 'user') + '\' + $file + '.log'
Write-Host "[$scriptName] logFile         : $logFile"

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
		"/norestart",
		"LicenseAccepted=`"0`"",
		"/L*V", # Log Verbose
		"$logFile",
		"/i", # Install file path
		"$installFile",
		"ADDLOCAL=ALL",
		"LISTENURL=http://+:${MsDepSvcPort}/MsDeployAgentService"
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

# Perform Install
executeExpression "`$process = Start-Process -FilePath `'msiexec`' -ArgumentList `'$argList`' $sessionControl"

$key = "HKLM:\SOFTWARE\Microsoft\IIS Extensions\MSDeploy\$installPath"
$name = 'InstallPath'

# Retrieve the install path from the registry key, if missing, halt with error
executeExpression "`$InstallPath = (Get-ItemProperty -Path `'$key`' -Name $name).$name"

write-host "Set environment variable MSDeployPath to $InstallPath"
[Environment]::SetEnvironmentVariable('MSDeployPath', "$InstallPath", 'User')

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
