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
} else {
	$media = 'c:\vagrant\.provision\install.wim'
    Write-Host "[$scriptName] media           : $media (default)"
}

$wimIndex = $args[2]
if ($wimIndex) {
    Write-Host "[$scriptName] wimIndex        : $wimIndex"
} else {
	$wimIndex = '2'
    Write-Host "[$scriptName] wimIndex        : $wimIndex (default, Standard Edition)"
}

# If media is not found, install will attempt to download from windows update
if ( Test-Path $media ) {
	$sourceOption = '/source:wim:' + $media + ":$wimIndex"
	Write-Host "[$scriptName] Media path found, using source option $sourceOption"
} else {
    Write-Host "[$scriptName] media path not found, will attempt to download from windows update."
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
			$managementFeatures =  ' /featurename:IIS-ASPNET45 /featurename:IIS-NetFxExtensibility45 /featurename:NetFx4Extended-ASPNET45 /featurename:NetFx3 /featurename:NetFx3ServerFeatures'
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
$featureList = "/featurename:IIS-WebServerRole /FeatureName:IIS-ApplicationDevelopment /FeatureName:IIS-ISAPIFilter /FeatureName:IIS-ISAPIExtensions /FeatureName:IIS-NetFxExtensibility /featurename:IIS-WebServerManagementTools /featurename:IIS-ManagementScriptingTools /featurename:IIS-Metabase /featurename:IIS-ManagementService /FeatureName:IIS-Security /FeatureName:IIS-BasicAuthentication /FeatureName:IIS-RequestFiltering /FeatureName:IIS-WindowsAuthentication"
executeExpression "dism /online /NoRestart /enable-feature /All $featureList $sourceOptiondism"
	
Write-Host
Write-Host "[$scriptName] Install ASP.NET"
executeExpression "dism /online /NoRestart /enable-feature /All $aspNET $sourceOptiondism"
	
Write-Host
Write-Host "[$scriptName] Rerun with all options to ensure all applied"
executeExpression "dism /online /NoRestart /enable-feature /All $featureList $aspNET $sourceOptiondism"

Write-Host
Write-Host "[$scriptName] List Web Server status"
executeExpression "dism /online /get-featureinfo /featurename:IIS-WebServer"

Write-Host
Write-Host "[$scriptName] Enable Remote Management in Registry"
if ($configuration -eq 'management') {
	executeExpression "`$process = Start-Process -FilePath `'Reg`' -ArgumentList `'Add HKLM\Software\Microsoft\WebManagement\Server /V EnableRemoteManagement /T REG_DWORD /D 1 /f`' $sessionControl"
}

executeExpression "`$process = Start-Process -FilePath `'net`' -ArgumentList `'start wmsvc`' $sessionControl"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
