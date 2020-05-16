# -*- mode: ruby -*-
# vi: set ft=ruby :

if ENV['OVERRIDE_IMAGE']
  OVERRIDE_IMAGE = ENV['OVERRIDE_IMAGE']
  puts "OVERRIDE_IMAGE specified, using box #{OVERRIDE_IMAGE}" 
else
  OVERRIDE_IMAGE = 'cdaf/WindowsServerStandard' # Server 2019 Core
  puts "OVERRIDE_IMAGE not specified, box is #{OVERRIDE_IMAGE}" 
end

if ENV['MAX_SERVER_TARGETS']
  MAX_SERVER_TARGETS = ENV['MAX_SERVER_TARGETS']
else
  MAX_SERVER_TARGETS = 1
end

if ENV['SCALE_FACTOR']
  SCALE_FACTOR = ENV['SCALE_FACTOR'].to_i
else
  SCALE_FACTOR = 1
end
vRAM = 1024 * SCALE_FACTOR
vCPU = SCALE_FACTOR

Vagrant.configure(2) do |allhosts|

  (1..MAX_SERVER_TARGETS).each do |i|
    allhosts.vm.define "server-#{i}" do |server|
      server.vm.box = "#{OVERRIDE_IMAGE}"
      
      # Align with Docker for remaining provisioning
      server.vm.provision 'shell', path: '.\automation\provisioning\mkdir.ps1', args: 'C:\deploy'

      # Vagrant specific for WinRM
      server.vm.provision 'shell', path: '.\automation\provisioning\CredSSP.ps1', args: 'server'
      server.vm.provider 'virtualbox' do |virtualbox, override|
        virtualbox.gui = false
        virtualbox.memory = "#{vRAM}"
        virtualbox.cpus = "#{vCPU}"
        override.vm.network 'private_network', ip: '172.16.17.101'
        override.vm.network 'forwarded_port', guest: 80, host: 80, auto_correct: true
        if ENV['SYNCED_FOLDER']
          override.vm.synced_folder "#{ENV['SYNCED_FOLDER']}", "/.provision" # equates to C:\.provision
        end
      end

      # Microsoft Hyper-V
      server.vm.provider 'hyperv' do |hyperv, override|
        hyperv.memory = "#{vRAM}"
        hyperv.cpus = "#{vCPU}"
        override.vm.hostname = "server-#{i}"
        override.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: "#{ENV['VAGRANT_SMB_USER']}", smb_password: "#{ENV['VAGRANT_SMB_PASS']}"
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
      virtualbox.gui = false
      virtualbox.memory = "#{vRAM}"
      virtualbox.cpus = "#{vCPU}"
      override.vm.network 'private_network', ip: '172.16.17.100'
      if ENV['SYNCED_FOLDER']
        override.vm.synced_folder "#{ENV['SYNCED_FOLDER']}", "/.provision" # equates to C:\.provision
      end
      (1..MAX_SERVER_TARGETS).each do |s|
        override.vm.provision 'shell', path: '.\automation\provisioning\addHOSTS.ps1', args: "172.16.17.10#{s} server-#{s}"
      end
      override.vm.provision 'shell', path: '.\automation\provisioning\CDAF.ps1'
    end

    # Hyper-V
    build.vm.provider 'hyperv' do |hyperv, override|
      hyperv.memory = "#{vRAM}"
      hyperv.cpus = "#{vCPU}"
      override.vm.hostname = 'build'
      override.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: "#{ENV['VAGRANT_SMB_USER']}", smb_password: "#{ENV['VAGRANT_SMB_PASS']}"
      override.vm.provision 'shell', path: '.\automation\provisioning\CDAF.ps1'
    end
  end

end