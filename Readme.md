Continuous Delivery Automation Framework for Windows
====================================================

For usage details, see https://github.com/cdaf/windows/blob/master/automation/Readme.md

For framework details, see the readme in the automation folder. For stable release packages see : http://cdaf.azurewebsites.net/

Desktop Testing
===============
This approach creates a desktop "build server" which allows the user to perform end-to-end continuous delivery testing.

Prerequisites
-------------
Oracle VirtualBox and Vagrant

Note: on Windows Server 2012 R2 need to manually install x86 (not 64 bit) C++ Redistributable.

edit  get_vm_status.ps1  to catch exception type  Exception  instead of  Microsoft.HyperV.PowerShell.VirtualizationException 

Create Desktop Build Server
---------------------------

To create a desktop environment, in an elevated powershell session, navigate to the solution root and run:

    vagrant up
    
Once the environment is running access the build server an execute the CD emulation

    vagrant powershell buildserver
    cd C:\vagrant
    .\automation\cdEmulate.bat
    

Direct PowerShell Access
------------------------

To access the buildserver using native remote PowerShell.
Allow credential delegation, on-off step needed on the host when using VirtualBox/Vagrant. 

    ./automation/provisioning/runner.bat CredSSP.ps1 client

Once delegation configured, the build emulation can be executed.

    $securePassword = ConvertTo-SecureString 'vagrant' -asplaintext -force
    $cred = New-Object System.Management.Automation.PSCredential ('vagrant', $securePassword)
    enter-pssession 127.0.0.1 -port 15985 -Auth CredSSP -credential $cred
    cd C:\vagrant
	.\automation\cdEmulate.bat

Cleanup and Destroy
-------------------
If change made that need to be checked in, clean the workspace:

	.\automation\cdEmulate.bat clean

Once finished with the environment, destroy using:

    vagrant destroy -f