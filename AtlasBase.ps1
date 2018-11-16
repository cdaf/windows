Param (
	[string]$emailTo,
	[string]$smtpServer,
	[string]$skipUpdates
)
$scriptName = 'AtlasBase.ps1'
$imageLog = 'c:\VagrantBox.txt'
cmd /c "exit 0"

# Write to standard out and file
function writeLog ($message) {
	Write-Host "[$scriptName] $message"
	Add-Content $imageLog "[$scriptName] $message"
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	writeLog "[$(date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { writeLog "`$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { writeLog "`$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { writeLog "`$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

# Exception Handling email sending
function emailAndExit ($exitCode) {
	if ($smtpServer) {
		Send-MailMessage -To "$emailTo" -From 'no-reply@cdaf.info' -Subject "[$scriptName] ERROR $exitCode" -SmtpServer "$smtpServer"
	}
	exit $exitCode
}

# Informational email notification 
function emailProgress ($subject) {
	if ($smtpServer) {
		Send-MailMessage -To "$emailTo" -From 'no-reply@cdaf.info' -Subject "[$scriptName] $subject" -SmtpServer "$smtpServer"
	}
}

emailProgress "starting, logging to $imageLog"

writeLog "---------- start ----------"

if ($emailTo) {
    writeLog "emailTo     : $emailTo"
} else {
    writeLog "emailTo     : (not specified, email will not be attempted)"
}

if ($smtpServer) {
    writeLog "smtpServer  : $smtpServer"
} else {
    writeLog "smtpServer  : (not specified, email will not be attempted)"
}

if ($skipUpdates) {
    writeLog "skipUpdates : $skipUpdates"
} else {
	$skipUpdates = 'yes'
    writeLog "skipUpdates : $skipUpdates (default)"
}

executeExpression "cd C:\"
executeExpression "mkdir windows-master"
executeExpression "cd windows-master"
$zipFile = "WU-CDAF.zip"
$url = "http://cdaf.io/static/app/downloads/$zipFile"
executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$PWD\$zipFile')"
executeExpression "Add-Type -AssemblyName System.IO.Compression.FileSystem"
executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory('$PWD\$zipfile', '$PWD')"
executeExpression "rm .\readme.md"
executeExpression "rm .\Vagrantfile"
executeExpression "rm .\WU-CDAF.zip"

writeLog "Enable Remote Desktop and Open firewall"
$obj = executeExpression "Get-WmiObject -Class `"Win32_TerminalServiceSetting`" -Namespace root\cimv2\terminalservices"
executeExpression "`$obj.SetAllowTsConnections(1,1)"
executeExpression "Set-NetFirewallRule -Name RemoteDesktop-UserMode-In-TCP -Enabled True"

writeLog "Disable User Account Controls (UAC)"
executeExpression "reg add HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA /d 0 /t REG_DWORD /f /reg:64"

writeLog "Ensure all adapters set to private (ignore failure if on DC)"
executeExpression "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private"

writeLog "configure the computer to receive remote commands"
executeExpression "Enable-PSRemoting -Force"

writeLog "Open Firewall for WinRM"
executeExpression "Set-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC -RemoteAddress Any"

writeLog "Allow arbitrary script execution"
executeExpression "Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force"

writeLog "Allow `"hop`""
executeExpression "Enable-WSManCredSSP -Role Server -Force"

writeLog "Settings to support Vagrant integration, Unencypted Remote PowerShell"
executeExpression "winrm set winrm/config `'@{MaxTimeoutms=`"1800000`"}`'"
executeExpression "winrm set winrm/config/service `'@{AllowUnencrypted=`"true`"}`'"
executeExpression "winrm set winrm/config/service/auth `'@{Basic=`"true`"}`'"
executeExpression "winrm set winrm/config/client/auth `'@{Basic=`"true`"}`'"

writeLog "Set to maximum (only applies to Server 2012, already set in 2016)"
executeExpression "winrm set winrm/config/winrs `'@{MaxConcurrentUsers=`"100`"}`'"
executeExpression "winrm set winrm/config/winrs `'@{MaxProcessesPerShell=`"2147483647`"}`'"
executeExpression "winrm set winrm/config/winrs `'@{MaxMemoryPerShellMB=`"2147483647`"}`'"
executeExpression "winrm set winrm/config/winrs `'@{MaxShellsPerUser=`"2147483647`"}`'"

writeLog "List settings for information"
Get-childItem WSMan:\localhost\Shell

writeLog "Disable password policy"
executeExpression "secedit /export /cfg c:\secpol.cfg"
executeExpression "(gc C:\secpol.cfg).replace(`"PasswordComplexity = 1`", `"PasswordComplexity = 0`") | Out-File C:\secpol.cfg"
executeExpression "secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas SECURITYPOLICY"
executeExpression "rm -force c:\secpol.cfg -confirm:`$false"

writeLog "Set default Administrator password to `'vagrant`'"
$admin = executeExpression "[adsi]`'WinNT://./Administrator,user`'"
executeExpression "`$admin.SetPassword(`'vagrant`')"
executeExpression "`$admin.UserFlags.value = `$admin.UserFlags.value -bor 0x10000" # Password never expires
executeExpression "`$admin.CommitChanges()" 

writeLog "Create the Vagrant user (with password vagrant) in the local administrators group, only if not existing"
if (([adsi]"WinNT://./vagrant,user").path ) { 
	writeLog "Vagrant user exists, no action required."
} else {
	$ADSIComp = executeExpression "[ADSI]`"WinNT://$Env:COMPUTERNAME,Computer`""
	$LocalUser = executeExpression "`$ADSIComp.Create(`'User`', `'vagrant`')"
	executeExpression "`$LocalUser.SetPassword(`'vagrant`')"
	executeExpression "`$LocalUser.SetInfo()"
	executeExpression "`$LocalUser.FullName = `'Vagrant Administrator`'"
	executeExpression "`$LocalUser.SetInfo()"
	executeExpression "`$LocalUser.UserFlags.value = `$LocalUser.UserFlags.value -bor 0x10000" # Password never expires
	executeExpression "`$LocalUser.CommitChanges()"
	$de = executeExpression "[ADSI]`"WinNT://$env:computername/Administrators,group`""
	executeExpression "`$de.psbase.Invoke(`'Add`',([ADSI]`"WinNT://$env:computername/vagrant`").path)"
}

if ( $skipUpdates -eq 'yes' ) {
    executeExpression "SC.EXE CONFIG wuauserv start= disabled"
    executeExpression "Stop-Service wuauserv"
    executeExpression "Get-Service wuauserv | select -property name,status,starttype | Format-Table"
	emailProgress "Base image complete (no updates applied), shutdown ..."
	executeExpression "shutdown /s /t 60"
	
} else {
	writeLog "Apply Windows Updates"
	executeExpression "./automation/provisioning/applyWindowsUpdates.ps1 no"
	emailProgress "Windows Updates applied, reboot ..."
	executeExpression "shutdown /r /t 60"
}

writeLog "---------- stop ----------"
exit 0