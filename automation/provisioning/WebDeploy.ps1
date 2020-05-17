Param (
  [string]$Installtype,
  [string]$MsDepSvcPort,
  [string]$version,
  [string]$mediaDir
)
$scriptName = 'WebDeploy.ps1'
$versionChoices = '2, 3.5 or 3.6' 

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

function listAndContinue {
	Write-Host "[$scriptName] Error accessing cache falling back to `$env:temp"
	$mediaDir = $env:temp
	$fullpath = $mediaDir + '\' + $file
	return $fullpath
}

cmd /c "exit 0"
Write-Host "`n[$scriptName] Install Web Deploy. As of Visual Studio 2015 Web Deploy build targets are automatically included, so the default action for this provisioner is now agent."
Write-Host "`n[$scriptName] ---------- start ----------"
if ($Installtype) {
    Write-Host "[$scriptName] Installtype  : $Installtype"
} else {
	$Installtype = 'agent'
    Write-Host "[$scriptName] Installtype  : $Installtype (default, choices agent or build)"
}

if ($MsDepSvcPort) {
    Write-Host "[$scriptName] MsDepSvcPort : $MsDepSvcPort"
} else {
	$MsDepSvcPort = '80'
    Write-Host "[$scriptName] MsDepSvcPort : $MsDepSvcPort (default)"
}

if ($version) {
    Write-Host "[$scriptName] version      : $version"
} else {
	$version = '3.6'
    Write-Host "[$scriptName] version      : $version (default, choices $versionChoices)"
}

if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir     : $mediaDir`n"
} else {
	$mediaDir = 'C:\.provision'
    Write-Host "[$scriptName] mediaDir     : $mediaDir (default)`n"
}

# Create media cache if missing
if ( Test-Path $mediaDir ) {
    Write-Host "`n[$scriptName] `$mediaDir ($mediaDir) exists"
} else {
	Write-Host "[$scriptName] Created $(mkdir $mediaDir)"
}

if ($env:interactive) {
    Write-Host "[$scriptName] `$env:interactive = `$env:interactive, run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
} else {
    $sessionControl = '-PassThru -Wait'
}

# Install path is used for reading from registry after install is complete
switch ($version) {
	'3.6' {
		$regKeyLeaf = '3'
		$file = 'WebDeploy_amd64_en-US.msi'
		$uri = 'http://download.microsoft.com/download/0/1/D/01DC28EA-638C-4A22-A57B-4CEF97755C6C/' + $file
	}
	'3.5' {
		$regKeyLeaf = '3'
		$file = 'WebDeploy_amd64_en-US.msi'
		$uri = 'http://download.microsoft.com/download/D/4/4/D446D154-2232-49A1-9D64-F5A9429913A4/' + $file
	}
	'2' {
		$regKeyLeaf = $version
		$file = 'WebDeploy_2_10_amd64_en-US.msi'
		$uri = 'http://download.microsoft.com/download/8/9/B/89B754A5-56F7-45BD-B074-8974FD2039AF/' + $file
	}
    default {
	    Write-Host "[$scriptName] version not supported, choices are $versionChoices"
    }
}

$key = "HKLM:\SOFTWARE\Microsoft\IIS Extensions\MSDeploy\$regKeyLeaf"
$name = 'InstallPath'

# Check for install path in registry key
if ( Test-Path -Path "$key" ) {
	$InstallPath = (Get-ItemProperty -Path "$key" -Name $name).$name
}
if ( $InstallPath ) {
	if ($Installtype -eq 'agent') {
		Write-Host "[$scriptName] Web Deploy already installed, requested install type is agent, verifying Agent is installed"
	} else {
		Write-Host "[$scriptName] Web Deploy already installed, no action attempted."
	}
} else {

	# Prepare Install Media
	$installFile = $mediaDir + '\' + $file
	Write-Host "[$scriptName] installFile = $installFile"
	
	$logFile = $env:TEMP + '\' + $file + '.log'
	Write-Host "[$scriptName] logFile     = $logFile`n"
	
	if ( Test-Path $installFile ) {
		Write-Host "[$scriptName] $installFile exists, download not required"
	} else {
		Write-Host "[$scriptName] $file does not exist in $mediaDir, listing contents"
		try {
			Get-ChildItem $mediaDir | Format-Table name
		    if(!$?) { $installFile = listAndContinue }
		} catch { $installFile = listAndContinue }

		if ( $env:http_proxy ) {
			Write-Host "[$scriptName] Attempt download using proxy"
			executeExpression "[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('$env:http_proxy')"
		} else {
			Write-Host "[$scriptName] Attempt download without proxy (set `$env:http_proxy to use)"
		}
		executeExpression "(New-Object System.Net.WebClient).DownloadFile('$uri', '$installFile')"
	}

	# Copy to temp dir in-case the media directory is a SMB mount
	$installFile = $env:TEMP + '\' + $file
	Copy-Item -Force "${mediaDir}\${file}" $installFile

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
	$proc = executeExpression "Start-Process -FilePath `'msiexec`' -ArgumentList `'$argList`' $sessionControl"
	if ( $proc.ExitCode -ne 0 ) {
		Write-Host "`n[$scriptName] Install Failed, see log file (c:\windows\logs\CBS\CBS.log) for details, listing last 40 lines`n"
		executeExpression "Get-Content 'c:\windows\logs\CBS\CBS.log' | select -Last 40"
		Write-Host "`n[$scriptName] Listing MSI log file`n"
		executeExpression "Get-Content $logFile"
		Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
	    exit $proc.ExitCode
	}
	
	# Retrieve the install path from the registry key, if missing, halt with error
	$InstallPath = executeExpression "(Get-ItemProperty -Path `'$key`' -Name $name).$name"
	
	write-host "Set environment variable MSDeployPath to $InstallPath"
	executeExpression "[Environment]::SetEnvironmentVariable('MSDeployPath', `'$InstallPath`', `'Machine`')"
	
	$failed = Select-String $logFile -Pattern "Installation failed"
	if ( $failed  ) { 
		Select-String $logFile -Pattern "Installation success or error status"
		exit 4900
	}
}

if ($Installtype -eq 'agent') {
	$service = executeExpression "Get-Service MsDepSvc"
	Write-Host "[$scriptName] Web Deploy agent is $($service.Status)"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0
