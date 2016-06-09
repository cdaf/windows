function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
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
			Write-Host "[$scriptName] Windows Server 2008R2/Win 7 or earlier, only including ASP .NET ..."
		} else {
			Write-Host "[$scriptName] Windows Server 2012/Win 8 or later, including ASP .NET 4.5 ..."
			$aspNET = $aspNET + ' /featurename:IIS-ASPNET45 /featurename:IIS-NetFxExtensibility45 /featurename:NetFx4Extended-ASPNET45 /featurename:NetFx3 /featurename:NetFx3ServerFeatures'
		}
	}
    default {
	    Write-Host "[$scriptName] configuration not supported, choices are $configChoices"
	    exit 100
    }
}

try {

	# to allow varying process behaviour, build as a string and then execute. $process is not used, it just suppresses process handle logging
	executeExpression "`$process = Start-Process -FilePath `'dism`' -ArgumentList `'/online /NoRestart /enable-feature /featurename:IIS-WebServerRole /FeatureName:IIS-ApplicationDevelopment $aspNET /FeatureName:IIS-ISAPIFilter /FeatureName:IIS-ISAPIExtensions /FeatureName:IIS-NetFxExtensibility /featurename:IIS-WebServerManagementTools /featurename:IIS-ManagementScriptingTools /featurename:IIS-IIS6ManagementCompatibility /featurename:IIS-Metabase /featurename:IIS-ManagementService /FeatureName:IIS-Security /FeatureName:IIS-BasicAuthentication /FeatureName:IIS-RequestFiltering /FeatureName:IIS-WindowsAuthentication`' $sessionControl"
	executeExpression "`$process = Start-Process -FilePath `'Reg`' -ArgumentList `'Add HKLM\Software\Microsoft\WebManagement\Server /V EnableRemoteManagement /T REG_DWORD /D 1 /f`' $sessionControl"
	executeExpression "`$process = Start-Process -FilePath `'net`' -ArgumentList `'start wmsvc`' $sessionControl"

} catch {
	Write-Host "[$scriptName] $media Install Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
