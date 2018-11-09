Param (
	[string]$hypervisor,
	[string]$emailTo,
	[string]$smtpServer,
	[string]$emailFrom,
	[string]$sysprep,
	[string]$stripDISM
)
$scriptName = 'AtlasImage.ps1'
$imageLog = 'c:\VagrantBox.txt'
cmd /c "exit 0"

# Write to standard out and file
function writeLog ($message) {
	Write-Host "[$scriptName] $message"
	Add-Content $imageLog "[$scriptName] $message"
}

# Use executeIgnoreExit to only trap exceptions, use executeExpression to trap all errors ($LASTEXITCODE is global)
function execute ($expression) {
	$error.clear()
	writeLog "[$(date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { writeLog "`$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { writeLog "`$error[0] = $error"; exit 3 }
}

function executeExpression ($expression) {
	execute $expression
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { writeLog "ERROR! Exiting with `$LASTEXITCODE = $LASTEXITCODE"; exit $LASTEXITCODE }
}

function executeIgnoreExit ($expression) {
	execute $expression
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { writeLog "Warning `$LASTEXITCODE = $LASTEXITCODE"; cmd /c "exit 0" }
}

# Exception Handling email sending
function emailAndExit ($exitCode) {
	if ($smtpServer) {
		Send-MailMessage -To "$emailTo" -From "$emailFrom" -Subject "[$scriptName][$hypervisor] ERROR $exitCode" -SmtpServer "$smtpServer"
	}
	exit $exitCode
}

# Informational email notification 
function emailProgress ($subject) {
	if ($smtpServer) {
		Send-MailMessage -To "$emailTo" -From "$emailFrom" -Subject "[$scriptName][$hypervisor] $subject" -SmtpServer "$smtpServer"
	}
}

emailProgress "starting, logging to $imageLog"

writeLog "---------- start ----------"
if ($hypervisor) {
    writeLog "hypervisor : $hypervisor"
} else {
	$hypervisor = 'virtualbox'
    writeLog "hypervisor : (not specified, defaulted to $hypervisor)"
}

if ($emailTo) {
    Write-Host "[$scriptName] emailTo    : $emailTo"
} else {
    Write-Host "[$scriptName] emailTo    : (not specified, email will not be attempted)"
}

if ($smtpServer) {
    Write-Host "[$scriptName] smtpServer : $smtpServer"
} else {
    Write-Host "[$scriptName] smtpServer : (not specified, email will not be attempted)"
}

if ($emailFrom) {
    Write-Host "[$scriptName] emailFrom  : $emailFrom"
} else {
    Write-Host "[$scriptName] emailFrom  : (not specified, email will not be attempted)"
}

if ($sysprep) {
    writeLog "sysprep    : $sysprep"
} else {
	$sysprep = 'yes'
    writeLog "sysprep    : $sysprep (default)"
}
	
if ($stripDISM) {
    writeLog "stripDISM  : $stripDISM"
} else {
	$stripDISM = 'no'
    writeLog "stripDISM  : $stripDISM (default)"
}
	
if ( $hypervisor -eq 'virtualbox' ) {
	$vbadd = '5.2.16'
	executeExpression ".\automation\provisioning\mountImage.ps1 $env:userprofile\VBoxGuestAdditions_${vbadd}.iso http://download.virtualbox.org/virtualbox/${vbadd}/VBoxGuestAdditions_${vbadd}.iso"
	$result = executeExpression "[Environment]::GetEnvironmentVariable(`'MOUNT_DRIVE_LETTER`', `'User`')"
	emailProgress "Guest Additiions requires manual intervention ..."
	
	executeExpression "`$proc = Start-Process -FilePath `"$result\VBoxWindowsAdditions-amd64.exe`" -ArgumentList `'/S`' -PassThru -Wait"
	executeExpression ".\automation\provisioning\mountImage.ps1 $env:userprofile\VBoxGuestAdditions_${vbadd}.iso"
	executeExpression "Remove-Item $env:userprofile\VBoxGuestAdditions_${vbadd}.iso"
} else {
	writeLog "Hypervisor ($hypervisor) not virtualbox, skip Guest Additions install"
}

if ( $stripDISM -eq 'yes' ) {
	writeLog "Remove the features that are not required, then remove media for available features that are not installed"
	executeExpression "@(`'Server-Media-Foundation`') | Remove-WindowsFeature"
	executeExpression "Get-WindowsFeature | ? { `$_.InstallState -eq `'Available`' } | Uninstall-WindowsFeature -Remove"
} else {
	writeLog "Strip DISM skipped (there is a bug in Windows Server 2016 where some disabled roles cannot be restored, e.g. ServerManager-Core-RSAT-Role-Tools"
}

writeLog "Deployment Image Servicing and Management (DISM.exe) clean-up"
executeIgnoreExit "Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase /Quiet"

writeLog "Windows Server Update service (WSUS) Clean-up"
executeExpression "Stop-Service wuauserv"
if ( Test-Path $env:systemroot\SoftwareDistribution ) {
    executeExpression "Remove-Item  $env:systemroot\SoftwareDistribution -Recurse -Force"
}

writeLog "Enable permissions to discard page file"
writeLog "`$System = GWMI Win32_ComputerSystem -EnableAllPrivileges"
$System = GWMI Win32_ComputerSystem -EnableAllPrivileges
executeExpression "`$System.AutomaticManagedPagefile = `$False"
writeLog "`$System.Put()"
$output = $System.Put()
writeLog "$output"

writeLog "Discard page file (is rebuilt at start-up)"
writeLog "`$CurrentPageFile = gwmi -query `"select * from Win32_PageFileSetting where name=`'c:\\pagefile.sys`'`""
$CurrentPageFile = gwmi -query "select * from Win32_PageFileSetting where name='c:\\pagefile.sys'"
executeExpression "`$CurrentPageFile.InitialSize = 512"
executeExpression "`$CurrentPageFile.MaximumSize = 512"
writeLog "`$CurrentPageFile.Put()"
$output = $CurrentPageFile.Put()
writeLog "$output"
 
writeLog "Prepare for Zeroing"
executeIgnoreExit "Optimize-Volume -DriveLetter C"

writeLog "See https://technet.microsoft.com/en-us/sysinternals/sdelete.aspx"
$zipFile = "SDelete.zip"
if (Test-Path "$zipFile") {
    writeLog "$zipFile exists, skip download."
} else {
    $url = "https://download.sysinternals.com/files/$zipFile"
    executeExpression "(New-Object System.Net.WebClient).DownloadFile(`"$url`", `"$PWD\$zipFile`")"
}
$secureDeleteExe = "sdelete.exe"
if (Test-Path "$secureDeleteExe") {
    writeLog "$secureDeleteExe exists, skip extraction."
} else {
    executeExpression "Add-Type -AssemblyName System.IO.Compression.FileSystem"
    executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory(`"$PWD\$zipFile`", `"$PWD`")"
}

writeLog "See https://peter.hahndorf.eu/blog/WorkAroundSysinternalsLicenseP.html"
executeExpression "& reg.exe ADD `"HKCU\Software\Sysinternals\SDelete`" /v EulaAccepted /t REG_DWORD /d 1 /f"
 
writeLog "Zero unused disk"
executeExpression "./$secureDeleteExe -z c:"

if ($sysprep -eq 'yes') {

	$scriptDir = "$env:windir/setup/scripts"
	if (Test-Path "$scriptDir") {
	    writeLog "$scriptDir exists, skip create."
	} else {
	    executeExpression "mkdir -Path $scriptDir"
	}
	
	# This script will be run once for sysprep'd machine 
	$setupCommand = "$scriptDir/SetupComplete.cmd"
	if (Test-Path "$setupCommand") {
	    writeLog "$setupCommand exists, skip create."
	} else {
	    executeExpression "Add-Content $scriptDir/SetupComplete.cmd `'netsh advfirewall firewall set rule name=`"Windows Remote Management (HTTP-in)`" new action=allow`'"
	    executeExpression "Add-Content $scriptDir/SetupComplete.cmd `'reg add HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA /d 0 /t REG_DWORD /f /reg:64`'"
	}
	executeExpression "cat $scriptDir/SetupComplete.cmd"
	
	# Close the WinRM port now, so Vagrant does not manage to connect during the system prep phase
	executeExpression "netsh advfirewall firewall set rule name=`'Windows Remote Management (HTTP-in)`' new action=block"
	
	writeLog "As per this URL there are implicit places windows looks for unattended files, I'm using C:\Windows\Panther\Unattend"
	executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'http://cdaf.io/static/app/downloads/unattend.xml`', `"$PWD\unattend.xml`")"
	
	$scriptDir = "C:\Windows\Panther\Unattend"
	if (Test-Path "$scriptDir") {
	    writeLog "$scriptDir exists, skip create."
	} else {
	    executeExpression "mkdir -Path $scriptDir"
	}
	
	$sysprepXML = "$scriptDir\unattend.xml"
	if (Test-Path "$sysprepXML") {
	    writeLog "$sysprepXML exists, skip create."
	} else {
	    executeExpression "Copy-Item $PWD\unattend.xml $scriptDir"
	}
	executeExpression "cat $scriptDir\unattend.xml"
	emailProgress "last comms, starting sysprep"
	executeExpression "& C:\windows\system32\sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:$scriptDir\unattend.xml"
	
} else {
	writeLog "sysprep = $sysprep, skipping unattended install and sysrep."
	emailProgress "last comms, sysprep = $sysprep, skipping unattended install and sysrep."
	executeExpression "shutdown /s /t 2"
}

writeLog "---------- stop ----------"
exit 0
