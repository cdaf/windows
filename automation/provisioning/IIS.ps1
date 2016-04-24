$scriptName = 'IIS.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"

try {
	Write-Host "[$scriptName] Start-Process -FilePath `'dism`' -ArgumentList `'/online /enable-feature /featurename:IIS-WebServerRole /FeatureName:IIS-ApplicationDevelopment /FeatureName:IIS-ASPNET /FeatureName:IIS-ISAPIFilter /FeatureName:IIS-ISAPIExtensions /FeatureName:IIS-NetFxExtensibility /featurename:IIS-WebServerManagementTools /featurename:IIS-IIS6ManagementCompatibility /featurename:IIS-Metabase /featurename:IIS-ManagementService /FeatureName:IIS-Security /FeatureName:IIS-BasicAuthentication /FeatureName:IIS-RequestFiltering /FeatureName:IIS-WindowsAuthentication`' -PassThru -Wait"
	$process = Start-Process -FilePath 'dism' -ArgumentList '/online /enable-feature /featurename:IIS-WebServerRole /FeatureName:IIS-ApplicationDevelopment /FeatureName:IIS-ASPNET /FeatureName:IIS-ISAPIFilter /FeatureName:IIS-ISAPIExtensions /FeatureName:IIS-NetFxExtensibility /featurename:IIS-WebServerManagementTools /featurename:IIS-IIS6ManagementCompatibility /featurename:IIS-Metabase /featurename:IIS-ManagementService /FeatureName:IIS-Security /FeatureName:IIS-BasicAuthentication /FeatureName:IIS-RequestFiltering /FeatureName:IIS-WindowsAuthentication' -PassThru -Wait

	Write-Host "[$scriptName] Start-Process -FilePath `'net`' -ArgumentList `'start wmsvc`' -PassThru -Wait"
	$process = Start-Process -FilePath 'net' -ArgumentList 'start wmsvc' -PassThru -Wait
} catch {
	Write-Host "[$scriptName] $scriptName Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
