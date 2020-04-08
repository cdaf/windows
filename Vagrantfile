# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

# SMB credentials are those for the user executing vagrant commands, if domain user, use @ format
# [Environment]::SetEnvironmentVariable('VAGRANT_SMB_USER', 'username', 'User')
# [Environment]::SetEnvironmentVariable('VAGRANT_SMB_PASS', 'p4ssWord!', 'User')

# If this environment variable is set, then the location defined will be used for media
# [Environment]::SetEnvironmentVariable('SYNCED_FOLDER', '/opt/.provision', 'Machine')
if ENV['SYNCED_FOLDER']
  synchedFolder = ENV['SYNCED_FOLDER']
end

# If this environment variable is set, RAM and CPU allocations for virtual machines are increase by this factor, so must be an integer
# [Environment]::SetEnvironmentVariable('SCALE_FACTOR', '2', 'Machine')
if ENV['SCALE_FACTOR']
  SCALE_FACTOR = ENV['SCALE_FACTOR'].to_i
else
  SCALE_FACTOR = 1
end
vRAM = 1024 * SCALE_FACTOR
vCPU = SCALE_FACTOR

Vagrant.configure(2) do |allhosts|

  allhosts.vm.define 'target' do |target|
    target.vm.box = 'cdaf/WindowsServerCore'
    
    # Align with Docker for remaining provisioning
    target.vm.provision 'shell', path: '.\automation\provisioning\mkdir.ps1', args: 'C:\deploy'

    # Vagrant specific for WinRM
    target.vm.provision 'shell', path: '.\automation\provisioning\CredSSP.ps1', args: 'server'
    target.vm.provider 'virtualbox' do |virtualbox, override|
      virtualbox.gui = false
      virtualbox.memory = "#{vRAM}"
      virtualbox.cpus = "#{vCPU}"
      override.vm.network 'private_network', ip: '172.16.17.101'
      if synchedFolder
        override.vm.synced_folder "#{synchedFolder}", "/.provision" # equates to C:\.provision
      end
      override.vm.network 'forwarded_port', guest: 5000, host: 35000, auto_correct: true
    end

    # Microsoft Hyper-V
    target.vm.provider 'hyperv' do |hyperv, override|
      override.vm.hostname = 'target-1'
      override.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: "#{ENV['VAGRANT_SMB_USER']}", smb_password: "#{ENV['VAGRANT_SMB_PASS']}"
    end
  end

  allhosts.vm.define 'build' do |build|
    build.vm.box = 'cdaf/WindowsServerCore'

    build.vm.provision 'shell', path: '.\automation\remote\capabilities.ps1'

    # Vagrant specific for WinRM
    build.vm.provision 'shell', path: '.\automation\provisioning\CredSSP.ps1', args: 'client'
    build.vm.provision 'shell', path: '.\automation\provisioning\trustedHosts.ps1', args: '*'
    build.vm.provision 'shell', path: '.\automation\provisioning\setenv.ps1', args: 'interactive yes User'
    build.vm.provision 'shell', path: '.\automation\provisioning\setenv.ps1', args: 'CDAF_DELIVERY VAGRANT Machine'
    build.vm.provision 'shell', path: '.\automation\provisioning\CDAF_Desktop_Certificate.ps1'

    # Oracle VirtualBox, relaxed configuration for Desktop environment
    build.vm.provider 'virtualbox' do |virtualbox, override|
      virtualbox.gui = false
      virtualbox.memory = "#{vRAM}"
      virtualbox.cpus = "#{vCPU}"
      override.vm.network 'private_network', ip: '172.16.17.100'
      if synchedFolder
        override.vm.synced_folder "#{synchedFolder}", "/.provision" # equates to C:\.provision
      end
      override.vm.provision 'shell', path: '.\automation\provisioning\addHOSTS.ps1', args: '172.16.17.101 target-1'
      override.vm.provision 'shell', path: '.\automation\provisioning\CDAF.ps1'
    end

    # Hyper-V
    build.vm.provider 'hyperv' do |hyperv, override|
      override.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: "#{ENV['VAGRANT_SMB_USER']}", smb_password: "#{ENV['VAGRANT_SMB_PASS']}"
      override.vm.provision 'shell', path: '.\automation\provisioning\CDAF.ps1'
    end
  end

end