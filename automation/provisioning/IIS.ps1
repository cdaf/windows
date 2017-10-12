# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

function executeRetry ($expression) {
	$exitCode = 1
	$wait = 10
	$retryMax = 3
	$retryCount = 0
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "[$scriptName][$retryCount] $expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
		} catch { echo $_.Exception|format-list -force; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; $exitCode = 3 }
		if ( $LASTEXITCODE -eq 3010 ) { cmd /c "exit 0" } # 3010 is a normal exit
	    if ( $lastExitCode -ne 0 ) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode "; $exitCode = $lastExitCode }
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with `$LASTEXITCODE = $exitCode. Log file ($env:windir\logs\dism\dism.log) summary follows...`n"
				Compare-Object (get-content "$env:windir\logs\dism\dism.log") (Get-Content "$env:temp\dism.log")
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
				sleep $wait
			}
		}
    }
}

# Create or reuse mount directory
function mountWim ($media, $wimIndex, $mountDir) {
	Write-Host "[$scriptName] Validate WIM source ${media}:${wimIndex} using Deployment Image Servicing and Management (DISM)"
	executeExpression "dism /get-wiminfo /wimfile:$media"
	Write-Host
	Write-Host "[$scriptName] Mount to $mountDir using Deployment Image Servicing and Management (DISM)"
	executeExpression "Dism /Mount-Image /ImageFile:$media /index:$wimIndex /MountDir:$mountDir /ReadOnly /Optimize /Quiet"
}

$scriptName = 'IIS.ps1'
$configChoices = 'management or server'

Write-Host
Write-Host "[$scriptName] Install Internet Information Services Role as ASP .NET server, with optional Management Service."
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$configuration = $args[0]
if ($configuration) {
    Write-Host "[$scriptName] configuration   : $configuration (choices $configChoices)"
} else {
	$configuration = 'server'
    Write-Host "[$scriptName] configuration   : $configuration (default, choices $configChoices)"
}

$media = $args[1]
if ($media) {
    Write-Host "[$scriptName] media           : $media"
	$wimIndex = $args[2]
	if ($wimIndex) {
	    Write-Host "[$scriptName] wimIndex        : $wimIndex"
	} else {
		$wimIndex = '2'
	    Write-Host "[$scriptName] wimIndex        : $wimIndex (default, Standard Edition)"
	}
} else {
    Write-Host "[$scriptName] media           : (not supplied)"
    Write-Host "[$scriptName] wimIndex        : (not applicable when media not supplied)"
}

$defaultMount = 'C:\mountdir'

# Create a baseline copy of the DISM log file, to use for logging informatio if there is an exception, note: this log is normally locked, so can't simply delete it
executeExpression "copy 'c:\windows\logs\dism\dism.log' $env:temp"

Write-Host
if ( $media ) {
	if ( Test-Path $media ) {
		Write-Host "[$scriptName] Media path ($media) found"
		if ($wimIndex) {
			Write-Host "[$scriptName] Index ($wimIndex) passed, treating media as Windows Imaging Format (WIM)"
			if ( Test-Path "$defaultMount" ) {
				if ( Test-Path "$defaultMount\windows" ) {
					Write-Host "[$scriptName] Default mount path found ($defaultMount\windows), found, mount not attempted."
				} else {
					mountWim "$media" "$wimIndex" '$defaultMount'
				}
			} else {
				Write-Host "[$scriptName] Create default mount directory to $defaultMount"
				mkdir $defaultMount
				mountWim "$media" "$wimIndex" '$defaultMount'
			}
			$sourceOption = "/Source:$defaultMount\windows /LimitAccess /Quiet"
		} else {
			$sourceOption = "/Source:$media /LimitAccess /Quiet"
			Write-Host "[$scriptName] Media path found, using source option $sourceOption"
		}
	} else {
		$sourceOption = "/Quiet"
	    Write-Host "[$scriptName] media path not found, will attempt to download from windows update/internet, with option $sourceOption."
	}
} else {
	$sourceOption = "/Quiet"
    Write-Host "[$scriptName] media path not supplied, will attempt to download from windows update/internet, with option $sourceOption."
}

# Cannot run interactive via remote PowerShell
if ($env:interactive) {
    Write-Host "[$scriptName] env:interactive : $env:interactive, run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
} else {
    $sessionControl = '-PassThru -Wait'
}

$aspNET = '/FeatureName:IIS-ASPNET'
switch ($configuration) {
	'server' {
	    Write-Host "[$scriptName] Server Configuration only, default port 80"
	}
	'management' {
	    Write-Host "[$scriptName] Server Configuration with Management Agent, requires ASP .NET 4.5"
		$aspNET = '/featurename:IIS-ASPNET45'
		# Windows Server 2008R2/Win 7 or earlier, use ASP .NET, otherwise, use ASP .NET 4.5
		if ( [Environment]::OSVersion.Version -le (new-object 'Version' 6,1) ) {
			Write-Host "[$scriptName]   Windows Server 2008R2/Win 7 or earlier, only including ASP .NET and backward compatibilty management tools ..."
			$managementFeatures = ' /featurename:IIS-IIS6ManagementCompatibility'
		} else {
			Write-Host "[$scriptName]   Windows Server 2012/Win 8 or later, including ASP .NET 4.5 ..."
			$managementFeatures =  ' /featurename:IIS-ASPNET45 /featurename:IIS-NetFxExtensibility45 /featurename:NetFx4Extended-ASPNET45'
		}
		$aspNET = $aspNET + $managementFeatures
	}
    default {
	    Write-Host "[$scriptName] configuration not supported, choices are $configChoices"
	    exit 100
    }
}

Write-Host
Write-Host "[$scriptName] Install Web Server"
$featureList = "/featurename:IIS-WebServerRole /FeatureName:IIS-ApplicationDevelopment /FeatureName:IIS-ISAPIFilter /FeatureName:IIS-ISAPIExtensions /featurename:IIS-WebServerManagementTools /featurename:IIS-ManagementScriptingTools /featurename:IIS-Metabase /featurename:IIS-ManagementService /FeatureName:IIS-Security /FeatureName:IIS-BasicAuthentication /FeatureName:IIS-RequestFiltering /FeatureName:IIS-WindowsAuthentication"
if ( $sourceOption -eq '/Quiet' ) {
	executeRetry "dism /online /NoRestart /enable-feature /All $featureList $sourceOption"
} else { 
	executeExpression "dism /online /NoRestart /enable-feature /All $featureList $sourceOption"
	if ( $lastExitCode -ne 0 ) {
		Write-Host "[$scriptName] DISM failed with `$lastExitCode = $lastExitCode, retry from WSUS/Internet"
		executeRetry "dism /online /NoRestart /enable-feature /All $featureList /Quiet"
	}
}	

Write-Host
Write-Host "[$scriptName] Install ASP.NET"
if ( $sourceOption -eq '/Quiet' ) {
	executeRetry "dism /online /NoRestart /enable-feature /All $aspNET $sourceOption"
} else { 
	executeExpression "dism /online /NoRestart /enable-feature /All $aspNET $sourceOption"
	if ( $lastExitCode -ne 0 ) {
		Write-Host "[$scriptName] DISM failed with `$lastExitCode = $lastExitCode, retry from WSUS/Internet"
		executeRetry "dism /online /NoRestart /enable-feature /All $aspNET /Quiet"
	}
}	
	
Write-Host
Write-Host "[$scriptName] List Web Server status"
executeExpression "dism /online /get-featureinfo /featurename:IIS-WebServer"

Write-Host
Write-Host "[$scriptName] Enable Remote Management in Registry"
if ($configuration -eq 'management') {
	executeExpression "`$process = Start-Process -FilePath `'Reg`' -ArgumentList `'Add HKLM\Software\Microsoft\WebManagement\Server /V EnableRemoteManagement /T REG_DWORD /D 1 /f`' $sessionControl"
}

executeExpression "`$process = Start-Process -FilePath `'net`' -ArgumentList `'start wmsvc`' $sessionControl"

if ( Test-Path "$defaultMount\windows" ) {
	Write-Host "[$scriptName] Dismount default mount path ($defaultMount)"
	executeExpression "Dism /Unmount-Image /MountDir:$defaultMount /Discard /Quiet"
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
