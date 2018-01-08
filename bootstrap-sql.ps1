Param (
	[string]$saPassword,
	[string]$dbaPassword,
	[string]$sqlServerMedia,
	[string]$mediaLocation
)

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

$scriptName = 'bootstrap-sql.ps1'

Write-Host "`n[$scriptName] ---------- start ----------"
if ($saPassword) {
    Write-Host "[$scriptName] saPassword     : `$saPassword"
} else {
	$saPassword = 'swUwe5aG'
    Write-Host "[$scriptName] saPassword     : $saPassword (default)"
}

if ($dbaPassword) {
    Write-Host "[$scriptName] dbaPassword    : `$dbaPassword"
} else {
	$dbaPassword = 'Passw0rd!'
    Write-Host "[$scriptName] dbaPassword    : $dbaPassword (default)"
}

if ($sqlServerMedia) {
    Write-Host "[$scriptName] sqlServerMedia : $sqlServerMedia"
} else {
	$sqlServerMedia = 'en_sql_server_2016_enterprise_with_service_pack_1_x64_dvd_9542382.iso'
    Write-Host "[$scriptName] sqlServerMedia : $sqlServerMedia (default)"
}

if ($mediaLocation) {
    Write-Host "[$scriptName] mediaLocation  : $mediaLocation"
} else {
	$mediaLocation = 'http://10.0.2.2/provision'
    Write-Host "[$scriptName] mediaLocation  : $mediaLocation (default)"
}

if ( Test-Path "./automation/provisioning" ) {
	$atomicPath = '.'
} else {
	if ( Test-Path "/vagrant" ) {
		$atomicPath = '/vagrant'
	} else {
	    Write-Host "[$scriptName] Cannot find CDAF directories in workspace or /vagrant, so downloading from internet"
		Write-Host "[$scriptName] Download Continuous Delivery Automation Framework"
		Write-Host "[$scriptName] `$zipFile = 'WU-CDAF.zip'"
		$zipFile = 'WU-CDAF.zip'
		Write-Host "[$scriptName] `$url = `"http://cdaf.io/static/app/downloads/$zipFile`""
		$url = "http://cdaf.io/static/app/downloads/$zipFile"
		executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$PWD\$zipFile')"
		executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
		executeExpression '[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$zipfile", "$PWD")'
		executeExpression 'cat .\automation\CDAF.windows'
		$atomicPath = '.'
	}
}
Write-Host "[$scriptName] `$atomicPath = $atomicPath"

if ( Test-Path "/sqlinstalled" ) {

	$initialDate = executeExpression "Get-Content /sqlinstalled"
	Write-Host "[$scriptName] $env:COMPUTERNAME sqlinstalled $initialDate, to force reinstallion, delete the /sqlinstalled file"

} else {

	executeExpression "$atomicPath/automation/provisioning/newUser.ps1 .\sqlSA $saPassword -passwordExpires no" # SQL Server Service Account
	executeExpression "$atomicPath/automation/provisioning/mountImage.ps1 `"`${env:TMP}\${sqlServerMedia}`" '${mediaLocation}/${sqlServerMedia}'"
	Write-Host "[$scriptName] `$mountDrive = [Environment]::GetEnvironmentVariable('MOUNT_DRIVE_LETTER', 'User')"
	$mountDrive = [Environment]::GetEnvironmentVariable('MOUNT_DRIVE_LETTER', 'User')
	executeExpression "$atomicPath/automation/provisioning/installSQLServer.ps1 .\sqlSA BUILTIN\Administrators MSSQLSERVER $mountDrive -password `$saPassword"
	executeExpression "$atomicPath/automation/provisioning/sqlAuthMode.ps1" # Allow mixed mode for SQL Authentication
	executeExpression "$atomicPath/automation/provisioning/sqlAddUser.ps1 dba -loginType SQLLogin -sqlPassword `$dbaPassword"
	executeExpression "$atomicPath/automation/provisioning/sqlSetLoginRole.ps1 dba sysadmin"
	executeExpression "$atomicPath/automation/provisioning/openFirewallPort.ps1 1433 'SQL Server'"
	if ( $workingDirectory ) { executeExpression "cd $workingDirectory" }

	Write-Host "[$scriptName] Set sqlinstalled run marker file`n"
	executeExpression "Add-Content /sqlinstalled '$(get-date)'"
	
	$initialDate = executeExpression "Get-Content /sqlinstalled"
    Write-Host "[$scriptName] Initialisation complete $initialDate, to force reinstallion, delete the /sqlinstalled file`n"
	
}

Write-Host "`n[$scriptName] ---------- stop ----------"
