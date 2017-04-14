Param (
  [string]$hypervisor,
  [string]$emailTo,
  [string]$smtpServer,
  [string]$sysprep
)
$scriptName = 'AtlasImage.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function emailAndExit ($exitCode) {
	if ($smtpServer) {
		executeExpression "Send-MailMessage -To `"$emailTo`" -From `'no-reply@cdaf.info`' -Subject `"$scriptName [$hypervisor] ERROR $exitCode`" -SmtpServer `"$smtpServer`""
	}
	exit $exitCode
}

function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	Add-Content "$imageLog" "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; Add-Content "$imageLog" "[$scriptName] `$? = $?"; emailAndExit 1 }
	} catch { echo $_.Exception|format-list -force; Add-Content "$imageLog" "$_.Exception|format-list"; emailAndExit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; Add-Content "$imageLog" "[$scriptName] `$error[0] = $error"; emailAndExit 3 }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($hypervisor) {
    Write-Host "[$scriptName] hypervisor : $hypervisor"
} else {
	$hypervisor = 'virtualbox'
    Write-Host "[$scriptName] hypervisor : (not specified, defaulted to $hypervisor)"
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

if ($sysprep) {
    Write-Host "[$scriptName] sysprep    : $sysprep"
} else {
	$sysprep = 'yes'
    Write-Host "[$scriptName] sysprep    : $sysprep (default)"
}

$imageLog = 'imageLog.txt'
if (Test-Path "$imageLog") {
    Write-Host "`n[$scriptName] Logfile exists ($imageLog), delete for new run."
	executeExpression "Remove-Item `"$imageLog`""
}
if ($smtpServer) {
	executeExpression "Send-MailMessage -To `"$emailTo`" -From `'no-reply@cdaf.info`' -Subject `"$scriptName [$hypervisor] starting, logging to $imageLog`" -SmtpServer `"$smtpServer`""
}

Write-Host "`n[$scriptName] Enable Remote Desktop and Open firewall"
$obj = executeExpression "Get-WmiObject -Class `"Win32_TerminalServiceSetting`" -Namespace root\cimv2\terminalservices"
executeExpression "`$obj.SetAllowTsConnections(1,1)"
executeExpression "Set-NetFirewallRule -Name RemoteDesktop-UserMode-In-TCP -Enabled True"

Write-Host "`n[$scriptName] Disable User Account Controls (UAC)"
executeExpression "reg add HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA /d 0 /t REG_DWORD /f /reg:64"

Write-Host "`n[$scriptName] Ensure all adapters set to private"
executeExpression "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private"

Write-Host "`n[$scriptName] configure the computer to receive remote commands"
executeExpression "Enable-PSRemoting -Force"

Write-Host "`n[$scriptName] Disable password policy"
executeExpression "secedit /export /cfg c:\secpol.cfg"
executeExpression "(gc C:\secpol.cfg).replace(`"PasswordComplexity = 1`", `"PasswordComplexity = 0`") | Out-File C:\secpol.cfg"
executeExpression "secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas SECURITYPOLICY"
executeExpression "rm -force c:\secpol.cfg -confirm:`$false"

Write-Host "`n[$scriptName] Set default Administrator password to `'vagrant`'"
$admin = executeExpression "[adsi]`'WinNT://./Administrator,user`'"
executeExpression "`$admin.SetPassword(`'vagrant`')"
executeExpression "`$admin.UserFlags.value = `$admin.UserFlags.value -bor 0x10000" # Password never expires
executeExpression "`$admin.CommitChanges()" 

Write-Host "`n[$scriptName] Create the Vagrant user (with password vagrant) in the local administrators group"
$ADSIComp = executeExpression "[ADSI]`"WinNT://$Env:COMPUTERNAME,Computer`""
$ADSIComp.Delete('User', 'vagrant')
$LocalUser = executeExpression "`$ADSIComp.Create(`'User`', `'vagrant`')"
executeExpression "`$LocalUser.SetPassword(`'vagrant`')"
executeExpression "`$LocalUser.SetInfo()"
executeExpression "`$LocalUser.FullName = `'Vagrant Administrator`'"
executeExpression "`$LocalUser.SetInfo()"
executeExpression "`$LocalUser.UserFlags.value = `$LocalUser.UserFlags.value -bor 0x10000" # Password never expires
executeExpression "`$LocalUser.CommitChanges()"
$de = executeExpression "[ADSI]`"WinNT://$env:computername/Administrators,group`""
executeExpression "`$de.psbase.Invoke(`'Add`',([ADSI]`"WinNT://$env:computername/vagrant`").path)"

Write-Host "`n[$scriptName] Open Firewall for WinRM"
executeExpression "Set-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC -RemoteAddress Any"

Write-Host "`n[$scriptName] Allow arbitrary script execution"
executeExpression "Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force"

Write-Host "`n[$scriptName] Allow `"hop`""
executeExpression "Enable-WSManCredSSP -Role Server -Force"

Write-Host "`n[$scriptName] settings to support Vagrant integration, Unencypted Remote PowerShell"
executeExpression "winrm set winrm/config `'@{MaxTimeoutms=`"1800000`"}`'"
executeExpression "winrm set winrm/config/service `'@{AllowUnencrypted=`"true`"}`'"
executeExpression "winrm set winrm/config/service/auth `'@{Basic=`"true`"}`'"
executeExpression "winrm set winrm/config/client/auth `'@{Basic=`"true`"}`'"

if ( $hypervisor -eq 'virtualbox' ) {
	if ($smtpServer) {
		executeExpression "Send-MailMessage -To `"$emailTo`" -From `'no-reply@cdaf.info`' -Subject `"$scriptName [$hypervisor] Guest Additiions requires manual intervention ...`" -SmtpServer `"$smtpServer`""
	}
	executeExpression ".\automation\provisioning\mountImage.ps1 $env:userprofile\VBoxGuestAdditions_5.1.18.iso http://download.virtualbox.org/virtualbox/5.1.18/VBoxGuestAdditions_5.1.18.iso"
	$result = executeExpression "[Environment]::GetEnvironmentVariable(`'MOUNT_DRIVE_LETTER`', `'User`')"
	executeExpression "`$proc = Start-Process -FilePath `"$result\VBoxWindowsAdditions-amd64.exe`" -ArgumentList `'/S`' -PassThru -Wait"
	executeExpression ".\automation\provisioning\mountImage.ps1 $env:userprofile\VBoxGuestAdditions_5.1.18.iso"
	executeExpression "Remove-Item $env:userprofile\VBoxGuestAdditions_5.1.18.iso"
} else {
	Write-Host "`n[$scriptName] Hypervisor ($hypervisor) not virtualbox, skip Guest Additions install"
}

Write-Host "`n[$scriptName] Remove the features that are not required, then remove media for available features that are not installed"
executeExpression "@(`'Server-Media-Foundation`') | Remove-WindowsFeature"
executeExpression "Get-WindowsFeature | ? { `$_.InstallState -eq `'Available`' } | Uninstall-WindowsFeature -Remove"

Write-Host "`n[$scriptName] Deployment Image Servicing and Management (DISM.exe) clean-up"
executeExpression "Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase"

Write-Host "`n[$scriptName] Windows Server Update service (WSUS) Clean-up"
executeExpression "Stop-Service wuauserv"
if ( Test-Path $env:systemroot\SoftwareDistribution ) {
    executeExpression "Remove-Item  $env:systemroot\SoftwareDistribution -Recurse -Force"
}

# Disabled, does not work in PowerShell 5.1, $System.Put() Exception calling "Put" with "0" argument(s): "Generic failure
#Write-Host "`n[$scriptName] Discard page file (is rebuilt at start-up)"
#$System = executeExpression "GWMI Win32_ComputerSystem -EnableAllPrivileges"
#executeExpression "`$System.AutomaticManagedPagefile = `$False"
#executeExpression "`$System.Put()"
#$CurrentPageFile = executeExpression "gwmi -query `"select * from Win32_PageFileSetting where name=`'c:\\pagefile.sys`'`""
#executeExpression "`$CurrentPageFile.InitialSize = 512"
#executeExpression "`$CurrentPageFile.MaximumSize = 512"
#executeExpression "`$CurrentPageFile.Put()"

Write-Host "`n[$scriptName] Prepare for Zeroing"
executeExpression "Optimize-Volume -DriveLetter C"

Write-Host "`n[$scriptName] See https://technet.microsoft.com/en-us/sysinternals/sdelete.aspx"
$zipFile = "SDelete.zip"
if (Test-Path "$zipFile") {
    Write-Host "`n[$scriptName] $zipFile exists, skip download."
} else {
    $url = "https://download.sysinternals.com/files/$zipFile"
    executeExpression "(New-Object System.Net.WebClient).DownloadFile(`"$url`", `"$PWD\$zipFile`")"
}
$secureDeleteExe = "sdelete.exe"
if (Test-Path "$secureDeleteExe") {
    Write-Host "`n[$scriptName] $secureDeleteExe exists, skip extraction."
} else {
    executeExpression "Add-Type -AssemblyName System.IO.Compression.FileSystem"
    executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory(`"$PWD\$zipFile`", `"$PWD`")"
}

Write-Host "`n[$scriptName] See https://peter.hahndorf.eu/blog/WorkAroundSysinternalsLicenseP.html"
executeExpression "& reg.exe ADD `"HKCU\Software\Sysinternals\SDelete`" /v EulaAccepted /t REG_DWORD /d 1 /f"
 
Write-Host "`n[$scriptName] Zero unused disk"
executeExpression "./$secureDeleteExe -z c:"

if ($sysprep -eq 'yes') {

	$scriptDir = "$env:windir/setup/scripts"
	if (Test-Path "$scriptDir") {
	    Write-Host "`n[$scriptName] $scriptDir exists, skip create."
	} else {
	    executeExpression "mkdir -Path $scriptDir"
	}
	
	$setupCommand = "$scriptDir/SetupComplete.cmd"
	if (Test-Path "$setupCommand") {
	    Write-Host "`n[$scriptName] $setupCommand exists, skip create."
	} else {
	    executeExpression "Add-Content $scriptDir/SetupComplete.cmd `'netsh advfirewall firewall set rule name=`"Windows Remote Management (HTTP-in)`" new action=allow`'"
	}
	executeExpression "cat $scriptDir/SetupComplete.cmd"
	executeExpression "netsh advfirewall firewall set rule name=`'Windows Remote Management (HTTP-in)`' new action=block"
	
	Write-Host "`n[$scriptName] As per this URL there are implicit places windows looks for unattended files, I'm using C:\Windows\Panther\Unattend"
	executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'http://cdaf.io/static/app/downloads/unattend.xml`', `"$PWD\unattend.xml`")"
	
	$scriptDir = "C:\Windows\Panther\Unattend"
	if (Test-Path "$scriptDir") {
	    Write-Host "`n[$scriptName] $scriptDir exists, skip create."
	} else {
	    executeExpression "mkdir -Path $scriptDir"
	}
	
	$sysprepXML = "$scriptDir\unattend.xml"
	if (Test-Path "$sysprepXML") {
	    Write-Host "`n[$scriptName] $sysprepXML exists, skip create."
	} else {
	    executeExpression "Copy-Item $PWD\unattend.xml $scriptDir"
	}
	executeExpression "cat $scriptDir\unattend.xml"
	if ($smtpServer) {
		executeExpression "Send-MailMessage -To `"$emailTo`" -From `'no-reply@cdaf.info`' -Subject `"$scriptName [$hypervisor] last comms, starting sysprep`" -SmtpServer `"$smtpServer`""
	}
	executeExpression "& C:\windows\system32\sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:$scriptDir\unattend.xml"
	
} else {
	Write-Host "[$scriptName] sysprep = $sysprep, skipping unattended install and sysrep."
	if ($smtpServer) {
		executeExpression "Send-MailMessage -To `"$emailTo`" -From `'no-reply@cdaf.info`' -Subject `"$scriptName [$hypervisor] last comms, sysprep = $sysprep, skipping unattended install and sysrep.`" -SmtpServer `"$smtpServer`""
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0