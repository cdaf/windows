# -*- mode: ruby -*-
# vi: set ft=ruby :

if ENV['OVERRIDE_IMAGE']
  OVERRIDE_IMAGE = ENV['OVERRIDE_IMAGE']
  puts "OVERRIDE_IMAGE specified, using box #{OVERRIDE_IMAGE}" 
else
  OVERRIDE_IMAGE = 'cdaf/WindowsServerStandard' # Server 2019 Desktop Experience
  puts "OVERRIDE_IMAGE not specified, use default box #{OVERRIDE_IMAGE}" 
end

if ENV['MAX_SERVER_TARGETS']
  MAX_SERVER_TARGETS = ENV['MAX_SERVER_TARGETS']
else
  MAX_SERVER_TARGETS = 1
end

Vagrant.configure(2) do |allhosts|

  (1..MAX_SERVER_TARGETS).each do |i|
    allhosts.vm.define "windows-#{i}" do |windows|
      windows.vm.box = "#{OVERRIDE_IMAGE}"
      windows.vm.provision 'shell', inline: 'Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose'
      
      # Align with Docker for remaining provisioning
      windows.vm.provision 'shell', path: '.\automation\provisioning\mkdir.ps1', args: 'C:\deploy'

      # Vagrant specific for WinRM
      windows.vm.provision 'shell', path: '.\automation\provisioning\CredSSP.ps1', args: 'server'
      windows.vm.provider 'virtualbox' do |virtualbox, override|
        override.vm.network 'private_network', ip: "172.16.17.10#{i}"
		    override.vm.synced_folder ".", "/vagrant", disabled: true
        if ENV['SYNCED_FOLDER']
          override.vm.synced_folder "#{ENV['SYNCED_FOLDER']}", "/.provision" # equates to C:\.provision
        end
      end

      # Set environment variable VAGRANT_DEFAULT_PROVIDER to 'hyperv'
      windows.vm.provider 'hyperv' do |hyperv, override|
        override.vm.hostname = "windows-#{i}"
    		override.vm.synced_folder ".", "/vagrant", disabled: true
        if ENV['SYNCED_FOLDER']
          override.vm.synced_folder "#{ENV['SYNCED_FOLDER']}", "/.provision", type: "smb", smb_username: "#{ENV['VAGRANT_SMB_USER']}", smb_password: "#{ENV['VAGRANT_SMB_PASS']}", mount_options: ["vers=2.1"]
        end
      end
    end
  end

  allhosts.vm.define 'build' do |build|
    build.vm.box = "#{OVERRIDE_IMAGE}"
    build.vm.provision 'shell', inline: 'Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose'
    build.vm.provision 'shell', path: '.\automation\remote\capabilities.ps1'

    # Vagrant specific for WinRM
    build.vm.provision 'shell', path: '.\automation\provisioning\CredSSP.ps1', args: 'client'
    build.vm.provision 'shell', path: '.\automation\provisioning\trustedHosts.ps1', args: '*'
    build.vm.provision 'shell', path: '.\automation\provisioning\setenv.ps1', args: 'interactive yes User'
    build.vm.provision 'shell', path: '.\automation\provisioning\setenv.ps1', args: 'CDAF_DELIVERY VAGRANT Machine'
    build.vm.provision 'shell', path: '.\automation\provisioning\setenv.ps1', args: 'CDAF_PS_USERNAME vagrant'
    build.vm.provision 'shell', path: '.\automation\provisioning\setenv.ps1', args: 'CDAF_PS_USERPASS vagrant'

    # Oracle VirtualBox, relaxed configuration for Desktop environment
    build.vm.provider 'virtualbox' do |virtualbox, override|
      override.vm.network 'private_network', ip: '172.16.17.100'
      (1..MAX_SERVER_TARGETS).each do |s|
        override.vm.provision 'shell', path: '.\automation\provisioning\addHOSTS.ps1', args: "172.16.17.10#{s} windows-#{s}.mshome.net"
      end
      override.vm.provision 'shell', path: '.\automation\provisioning\CDAF.ps1'
      override.vm.provision 'shell', path: '.\automation\provisioning\CDAF.ps1', args: '-action buildonly'
      override.vm.provision 'shell', path: '.\automation\provisioning\CDAF.ps1', args: '-action packageonly'
      override.vm.provision 'shell', path: '.\automation\provisioning\CDAF.ps1', args: '-action cionly'
      override.vm.provision 'shell', path: '.\automation\provisioning\CDAF.ps1', args: '-action cdonly'
    end

    # Set environment variable VAGRANT_DEFAULT_PROVIDER to 'hyperv'
    build.vm.provider 'hyperv' do |hyperv, override|
      override.vm.hostname = 'build'
      override.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: "#{ENV['VAGRANT_SMB_USER']}", smb_password: "#{ENV['VAGRANT_SMB_PASS']}", mount_options: ["vers=2.1"]
      override.vm.provision 'shell', path: '.\automation\provisioning\CDAF.ps1'
      override.vm.provision 'shell', path: '.\automation\provisioning\CDAF.ps1', args: '-action buildonly'
      override.vm.provision 'shell', path: '.\automation\provisioning\CDAF.ps1', args: '-action packageonly'
      override.vm.provision 'shell', path: '.\automation\provisioning\CDAF.ps1', args: '-action cionly'
      override.vm.provision 'shell', path: '.\automation\provisioning\CDAF.ps1', args: '-action cdonly'
    end
  end

end