# Manual process for VirtualBox Image Construction

Working on building using Packer, however, will endevour to keep this document aligned for reference puposes.

## Image Preparation

Enable Remote Desktop and Open firewall

    $obj = Get-WmiObject -Class "Win32_TerminalServiceSetting" -Namespace root\cimv2\terminalservices
    $obj.SetAllowTsConnections(1,1)
    Set-NetFirewallRule -Name RemoteDesktop-UserMode-In-TCP -Enabled True

Ensure all adapters set to private

    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private  

configure the computer to receive remote commands
http://technet.microsoft.com/en-us/library/hh849694.aspx

    Enable-PSRemoting -Force

Disable password policy

    secedit /export /cfg c:\secpol.cfg
    (gc C:\secpol.cfg).replace("PasswordComplexity = 1", "PasswordComplexity = 0") | Out-File C:\secpol.cfg
    secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas SECURITYPOLICY
    rm -force c:\secpol.cfg -confirm:$false

Change default Administrator user to Vagrant

    $admin=[adsi]"WinNT://./Administrator,user"
    $admin.SetPassword("vagrant")
    $admin.UserFlags.value = $admin.UserFlags.value -bor 0x10000 # Password never expires
    $admin.CommitChanges() 

Add the Vagrant user in the local administrators group

    $ADSIComp = [ADSI]"WinNT://$Env:COMPUTERNAME,Computer"
    $LocalUser = $ADSIComp.Create("User", "vagrant")
    $LocalUser.SetPassword("vagrant")
    $LocalUser.SetInfo()
    $LocalUser.FullName = "Vagrant Administrator"
    $LocalUser.SetInfo()
    $LocalUser.UserFlags.value = $LocalUser.UserFlags.value -bor 0x10000 # Password never expires
    $LocalUser.CommitChanges()
    $de = [ADSI]"WinNT://$env:computername/Administrators,group"
    $de.psbase.Invoke("Add",([ADSI]"WinNT://$env:computername/vagrant").path)

Insert Guest Additions CD image and reboot from prompt

    D:\VBoxWindowsAdditions-amd64.exe

After reboot, logon as vagrant# Disable EIP in Server Management then disable Server Management automatically opening

    $securePassword = ConvertTo-SecureString 'vagrant' -asplaintext -force
    $cred = New-Object System.Management.Automation.PSCredential ('vagrant', $securePassword)
    enter-pssession 127.0.0.1 -port 15985 -Auth CredSSP -credential $cred 

Create a admin PowerShell link for the following

    reg add HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA /d 0 /t REG_DWORD /f /reg:64

Settings to support Vagrant integration, Unencypted Remote PowerShell

    winrm set winrm/config '@{MaxTimeoutms="1800000"}'
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    winrm set winrm/config/service/auth '@{Basic="true"}'

Check the defaults, as of 2016, set to maximum, to set for Windows Server 2012 R2

    dir WSMan:\localhost\Shell

    Type            Name                           SourceOfValue   Value
    ----            ----                           -------------   -----
    System.String   AllowRemoteShellAccess                         true
    System.String   IdleTimeout                                    7200000
    System.String   MaxConcurrentUsers                             10
    System.String   MaxShellRunTime                                2147483647
    System.String   MaxProcessesPerShell                           25
    System.String   MaxMemoryPerShellMB                            1024
    System.String   MaxShellsPerUser                               30

    winrm set winrm/config/winrs '@{MaxConcurrentUsers="100"}'
    winrm set winrm/config/winrs '@{MaxProcessesPerShell="2147483647"}'
    winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2147483647"}'
    winrm set winrm/config/winrs '@{MaxShellsPerUser="2147483647"}'

    Type            Name                           SourceOfValue   Value
    ----            ----                           -------------   -----
    System.String   AllowRemoteShellAccess                         true
    System.String   IdleTimeout                                    7200000
    System.String   MaxConcurrentUsers                             100  # Note: this is 2147483647 in 2016.
    System.String   MaxShellRunTime                                2147483647
    System.String   MaxProcessesPerShell                           2147483647
    System.String   MaxMemoryPerShellMB                            2147483647
    System.String   MaxShellsPerUser                               2147483647

Open Firewall for WinRM

    Set-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC -RemoteAddress Any

Allow arbitrary script execution
TODO: Set to all without prompt

    Set-ExecutionPolicy -ExecutionPolicy Unrestricted

Allow "hop"

    Enable-WSManCredSSP -Force -Role Server

Remove (not uninstall yet) the features that are currently enabled, GUI ...

    @('Server-Media-Foundation', 'Powershell-ISE') | Remove-WindowsFeature

... core

    @('Server-Media-Foundation') | Remove-WindowsFeature

Now we can iterate over every feature that is not installed but 'Available' and physically uninstall them from disk:

    Get-WindowsFeature | ? { $_.InstallState -eq 'Available' } | Uninstall-WindowsFeature -Remove

Apply windows updates

    sconfig
    >6
    >R # don't bother with optional updates
    >A

    Stop-Service wuauserv
    Remove-Item  $env:systemroot\SoftwareDistribution -Recurse -Force

Shutdown to apply pagefile and remove install media

    shutdown /s /t 0

## On host

In VirtualBox remove media

## On Image

Perform from console or RDP as this will close the WinRM (Remote Powershell) connections
From https://github.com/mitchellh/vagrant/issues/7680 (in the link, name="WinRM-HTTP")
See also https://technet.microsoft.com/en-us/library/cc766314(v=ws.10).aspx

    mkdir -Path $env:windir/setup/scripts/
    Add-Content $env:windir/setup/scripts/SetupComplete.cmd 'netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-in)" new action=allow'
    cat $env:windir/setup/scripts/SetupComplete.cmd
    netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-in)" new action=block

Cleanup WinSXS update debris

    Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
    Optimize-Volume -DriveLetter C

Cleanup Trim pagefile (windows rebuilds that on start-up)

    $System = GWMI Win32_ComputerSystem -EnableAllPrivileges
    $System.AutomaticManagedPagefile = $False
    $System.Put()
    $CurrentPageFile = gwmi -query "select * from Win32_PageFileSetting where name='c:\\pagefile.sys'"
    $CurrentPageFile.InitialSize = 512
    $CurrentPageFile.MaximumSize = 512
    $CurrentPageFile.Put()

From http://huestones.co.uk/node/305, important especially for VirtualBox

    cd ~
    $zipFile = "SDelete.zip"
    $url = "https://download.sysinternals.com/files/$zipFile"
    (New-Object System.Net.WebClient).DownloadFile($url, "$PWD\$zipFile") 
    Add-Type -AssemblyName System.IO.Compression.FileSystem 
    [System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$zipfile", "$PWD") 
    ./sdelete.exe -z c:

As per this URL, https://technet.microsoft.com/en-us/library/cc749415(v=ws.10).aspx
there are implicit places windows looks for unattended files, I'm using C:\Windows\Panther\Unattend

    cd ~
    (New-Object System.Net.WebClient).DownloadFile('http://cdaf.io/static/app/downloads/unattend.xml', "$PWD\unattend.xml")
    mkdir C:\Windows\Panther\Unattend
    Copy-Item $PWD\unattend.xml C:\Windows\Panther\Unattend\
    cat C:\Windows\Panther\Unattend\unattend.xml
    C:\windows\system32\sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\Panther\Unattend\unattend.xml

# On the host

Compress the HDD and pack the image

    $boxName = 'WindowsServer'
    $packageFile = $boxname + '.box'
    & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" modifyhd "C:\Users\jules\VirtualBox VMs\${boxName}\${boxName}.vdi" --compact  

Create the .box package

    (New-Object System.Net.WebClient).DownloadFile('http://cdaf.io/static/app/downloads/Vagrantfile', "$PWD\Vagrantfile") 
    vagrant package --base $boxName --output $packageFile --vagrantfile Vagrantfile
    vagrant box add $boxName $packageFile --force

Test time

    mkdir temp
    cd temp
    vagrant init $boxName
    vagrant up
    vagrant powershell default

Now clean-up

    vagrant destroy -f
    cd ..; Remove-Item temp -Force -Recurse
    vagrant box remove $boxName