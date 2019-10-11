Param (
	[string]$appID,
	[string]$tenantID,
	[string]$password
)

$scriptName = 'maven-deploy-settings.ps1'

cmd /c "exit 0"
# Use the CDAF provisioning helpers
Write-Host "`n[$scriptName] ---------- start ----------`n"

$mavenSettings = "${env:USERPROFILE}\.m2"
if ( Test-Path "$mavenSettings\settings.xml" ) {
	Write-Host "[$scriptName] $mavenSettings\settings.xml exits, so not attempting changes"
} else {
	Write-Host "[$scriptName] Configure Maven settings for Azure Service Principal`n"
	if ( ! (Test-Path "$mavenSettings" )) {
		Write-Host "[$scriptName] Created $(mkdir $mavenSettings)"
	}

	Add-Content "$mavenSettings/settings.xml" '<?xml version="1.0" encoding="UTF-8"?>'
	Add-Content "$mavenSettings/settings.xml" '<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"'
	Add-Content "$mavenSettings/settings.xml" '	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
	Add-Content "$mavenSettings/settings.xml" '	xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">'
	Add-Content "$mavenSettings/settings.xml" '	<servers>'
	Add-Content "$mavenSettings/settings.xml" '		<server>'
	Add-Content "$mavenSettings/settings.xml" '			<id>azure-auth</id>'
	Add-Content "$mavenSettings/settings.xml" '			<configuration>'
	Add-Content "$mavenSettings/settings.xml" "				<client>${appID}</client>"
	Add-Content "$mavenSettings/settings.xml" "				<tenant>${tenantID}</tenant>"
	Add-Content "$mavenSettings/settings.xml" "				<key>${password}</key>"
	Add-Content "$mavenSettings/settings.xml" '				<environment>AZURE</environment>'
	Add-Content "$mavenSettings/settings.xml" '			</configuration>'
	Add-Content "$mavenSettings/settings.xml" '		</server>'
	Add-Content "$mavenSettings/settings.xml" '	</servers>'
	Add-Content "$mavenSettings/settings.xml" '</settings>'
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0 