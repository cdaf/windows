$scriptName = 'IIS.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"

try {
	Write-Host "[$scriptName] Start-Process -FilePath `'dism`' -ArgumentList `'/online /enable-feature /featurename:IIS-WebServerRole /featurename:IIS-WebServerManagementTools /featurename:IIS-ManagementService`' -PassThru -wait -Verb RunAs"
	$proc = Start-Process -FilePath 'dism' -ArgumentList '/online /enable-feature /featurename:IIS-WebServerRole /featurename:IIS-WebServerManagementTools /featurename:IIS-ManagementService' -PassThru -wait -Verb RunAs
	  
	Write-Host "[$scriptName] Start-Process -FilePath `'net`' -ArgumentList `'start wmsvc`' -PassThru -wait -Verb RunAs"
	$proc = Start-Process -FilePath 'net' -ArgumentList 'start wmsvc' -PassThru -wait -Verb RunAs
} catch {
	Write-Host "[$scriptName] $scriptName Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
