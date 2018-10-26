[![cdaf version](automation/badge.svg)](http://cdaf.io)

# Continuous Delivery Automation Framework for Windows

The automation framework provides a "lowest common denominator" approach, where underlying action are implemented in bash.

This automation framework functionality is based on user defined solution files. By default the /solution folder stores these files, however, a stand alone folder, in the solution root is supported, identified by the CDAF.solution file in the root.

## Why use CDAF

To provide a consistent approach to Continuous Delivery and leverage the efforts of others to provide greater reusability and easier problem determination. CDAF will provide the building blocks for common tasks, with rich logging and exeception handling. The CDAf provides toolset configuration guidance, keeping the actions loosely coupled with the toolset, to allow visibilty and traceability through source control rather than direct changes.

## Why not have a shared folder for CDAF on the system

CDAF principles are to have a minimum level of system dependency. By having solution specific copies each solution can use differing versions of CDAF, and once a solution is upgraded, that upgrade will be propogated to all uses (at next update/pull/get) where a system provisioned solution will requrie all users to update to the same version, even if their current solution has not been tested for this system wide change.

For usage details, see https://github.com/cdaf/windows/blob/master/automation/Readme.md

For framework details, see the readme in the automation folder. For stable release packages see : http://cdaf.io

To download and extract this repository

    curl -Outfile windows-master.zip https://codeload.github.com/cdaf/windows/zip/master
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\windows-master.zip", "$PWD") 

# Desktop Testing

This approach creates a desktop "build server" which allows the user to perform end-to-end continuous delivery testing.

## VirtualBox

Oracle VirtualBox and Vagrant

Note: on Windows Server 2012 R2 need to manually install x86 (not 64 bit) C++ Redistributable.

## Hyper-V

Install from the Windows features

    Dism /online /enable-feature /all /featurename:Microsoft-Hyper-V

# Create Desktop Environment

To create a desktop environment, navigate to the solution root and run:

    vagrant up
    
## Continuous Delivery Testing

Once the environment is running access the build server an execute the CD emulation. Note: On a Linux host bash Python WINRM can be used to provide native PowerShell access.

    vagrant powershell buildserver
    cd C:\vagrant
    .\automation\cdEmulate.bat
   

## Direct PowerShell Access

To access the buildserver using native remote PowerShell.
Allow credential delegation, on-off step needed on the host when using VirtualBox/Vagrant. 

    ./automation/provisioning/runner.bat CredSSP.ps1 client

Once delegation configured, the build emulation can be executed.

    $securePassword = ConvertTo-SecureString 'vagrant' -asplaintext -force
    $cred = New-Object System.Management.Automation.PSCredential ('vagrant', $securePassword)
    enter-pssession 127.0.0.1 -port 15985 -Auth CredSSP -credential $cred
    cd C:\vagrant
	.\automation\cdEmulate.bat

## Cleanup and Destroy

If change made that need to be checked in, clean the workspace:

	.\automation\cdEmulate.bat clean

Once finished with the environment, destroy using:

    vagrant destroy -f
    
# Vagrant Boxes

Vagrant box images available here https://app.vagrantup.com/cdaf are build initially for Hyper-V using AtlasBase.ps1. This is cloned in VirtualBox and then both images are prepared using AtlasImage.ps1. Finally the images are packaged on the Hyper-V and VirtualBox hosts using AtlasPackage.ps1. The resulting .box files are uploaded to Vagrantup.

## Related Material

The following links have contributed to the construction of the Atlas scripts

 * https://www.vagrantup.com/docs/virtualbox/boxes.html
 * http://www.hurryupandwait.io/blog/in-search-of-a-light-weight-windows-vagrant-box
 * http://huestones.co.uk/node/305
 * https://stackoverflow.com/questions/39469452/installing-removed-windows-features/46985832#46985832