Continuous Delivery Automation Framework for Windows
====================================================

For usage details, see : https://github.com/cdaf/windows/blob/master/automation/Readme.md

For framework details, see the readme in the automation folder. For stable release packages see : http://cdaf.azurewebsites.net/

Desktop Testing
===============
This approach creates a desktop "build server" which allows the user to perform end-to-end continuous delivery testing.

Prerequisites
-------------
Oracle VirtualBox and Vagrant

# Known Issue Vagrant 1.8.1
    C:\HashiCorp\Vagrant\embedded\gems\gems\vagrant-1.8.1\plugins\providers\hyperv\scripts\get_vm_status.ps1 : Unable to find type

edit  get_vm_status.ps1  to catch exception type  Exception  instead of  Microsoft.HyperV.PowerShell.VirtualizationException 

Create Desktop Build Server
---------------------------

To create a desktop environment, in an elevated powershell session, navigate to the solution root and run:

    vagrant up

Continuous Delivery Testing
---------------------------

To allow delegated elevation on the build server, on-off step needed to allow delegation. 

    Enable-WSManCredSSP -Role client -DelegateComputer * -Force

TODO: how do I set this via powershell? 

Get-ItemProperty HKLM:\Software\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly

1            : wsman/*

Once delegation configured, the build emulation can be executed.

    $securePassword = ConvertTo-SecureString 'vagrant' -asplaintext -force
    $cred = New-Object System.Management.Automation.PSCredential ('vagrant', $securePassword)
    enter-pssession 127.0.0.1 -port 25985 -Auth CredSSP -credential $cred
    cd C:\vagrant
	.\automation\cdEmulate.bat

Cleanup and Destroy
-------------------
If change made that need to be checked in, clean the workspace:

	.\automation\cdEmulate.bat clean

Once finished with the environment, destroy using:

    vagrant destroy -f