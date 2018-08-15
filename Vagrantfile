# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

# Zip Package creation requires PowerShell v3 or above and .NET 4.5 or above.

# Hyper-V uses SMB, the credentials are those for the user executing vagrant commands, if domain user, use @ format
# [Environment]::SetEnvironmentVariable('VAGRANT_DEFAULT_PROVIDER', 'hyperv', 'Machine')
# [Environment]::SetEnvironmentVariable('VAGRANT_SMB_USER', 'username', 'User')
# [Environment]::SetEnvironmentVariable('VAGRANT_SMB_PASS', 'p4ssWord!', 'User')

# Different VM images can be used by changing this variable, for example to use Windows Server 2016 with GUI
# $env:OVERRIDE_IMAGE = 'cdaf/WindowsServer'
if ENV['OVERRIDE_IMAGE']
  vagrantBox = ENV['OVERRIDE_IMAGE']
else
  vagrantBox = 'cdaf/WindowsServerStandard'
end

# If this environment variable is set, RAM and CPU allocations for virtual machines are increase by this factor, so must be an integer
# [Environment]::SetEnvironmentVariable('SCALE_FACTOR', '2', 'Machine')
if ENV['SCALE_FACTOR']
  scale = ENV['SCALE_FACTOR'].to_i
else
  scale = 1
end
if ENV['BASE_MEMORY']
  baseRAM = ENV['BASE_MEMORY'].to_i
else
  baseRAM = 1024
end

vRAM = baseRAM * scale
vCPU = scale

# This is provided to make scaling easier
MAX_SERVER_TARGETS = 1

# If this environment variable is set, then the location defined will be used for media
# [Environment]::SetEnvironmentVariable('SYNCED_FOLDER', '/opt/.provision', 'Machine')
if ENV['SYNCED_FOLDER']
  synchedFolder = ENV['SYNCED_FOLDER']
end

Vagrant.configure(2) do |config|

  # Build Server connects to this host to perform deployment
  (1..MAX_SERVER_TARGETS).each do |i|
    config.vm.define "server-#{i}" do |server|
      server.vm.box = "#{vagrantBox}"
      server.vm.communicator = 'winrm'
      server.vm.boot_timeout = 600  # 10 minutes
      server.winrm.timeout =   1800 # 30 minutes
      server.winrm.retry_limit = 10
      server.winrm.username = "vagrant" # Making defaults explicit
      server.winrm.password = "vagrant" # Making defaults explicit
      server.vm.graceful_halt_timeout = 180 # 3 minutes

      server.vm.provision 'shell', path: './automation/remote/capabilities.ps1'
      (1..MAX_SERVER_TARGETS).each do |s|
        server.vm.provision 'shell', path: './automation/provisioning/addHOSTS.ps1', args: "172.16.17.10#{s} server-#{s}.sky.net"
      end
      server.vm.provision 'shell', path: './automation/provisioning/mkdir.ps1', args: 'C:\deploy'
  
      # Oracle VirtualBox with private NAT has insecure deployer keys for desktop testing
      server.vm.provider 'virtualbox' do |virtualbox, override|
        virtualbox.memory = "#{vRAM}"
        virtualbox.cpus = "#{vCPU}"
        virtualbox.gui = false
        override.vm.network 'private_network', ip: "172.16.17.10#{i}"
        override.vm.hostname  = "server-#{i}" # Cannot set to FQDN
        if synchedFolder
          override.vm.synced_folder "#{synchedFolder}", "/.provision" # equates to C:\.provision
        end
        override.vm.network 'forwarded_port', guest:   80, host: 30080, auto_correct: true
        override.vm.provision 'shell', path: './automation/provisioning/CredSSP.ps1', args: 'server'
      end
      
      # Microsoft Hyper-V does not support NAT or setting hostname. vagrant up server-1 --provider hyperv
      server.vm.provider 'hyperv' do |hyperv, override|
        hyperv.vmname = "windows-target"
        hyperv.memory = "#{vRAM}"
        hyperv.cpus = "#{vCPU}"
        hyperv.ip_address_timeout = 300 # 5 minutes, default is 2 minutes (120 seconds)
        override.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: "#{ENV['VAGRANT_SMB_USER']}", smb_password: "#{ENV['VAGRANT_SMB_PASS']}"
      end
    end
  end

  # Build Server, fills the role of the build agent and delivers to the host above
  config.vm.define 'build' do |build|
    build.vm.box = "#{vagrantBox}"
    build.vm.communicator = 'winrm'
    build.vm.boot_timeout = 600  # 10 minutes
    build.winrm.timeout =   1800 # 30 minutes
    build.winrm.retry_limit = 10
    build.winrm.username = "vagrant" # Making defaults explicit
    build.winrm.password = "vagrant" # Making defaults explicit
    build.vm.graceful_halt_timeout = 180 # 3 minutes
    build.vm.provision 'shell', path: './automation/remote/capabilities.ps1'
    
    # Oracle VirtualBox with private NAT has insecure deployer keys for desktop testing
    build.vm.provider 'virtualbox' do |virtualbox, override|
      virtualbox.name = 'windows-build'
      virtualbox.memory = "#{vRAM}"
      virtualbox.cpus = "#{vCPU}"
      virtualbox.gui = false
      override.vm.network 'private_network', ip: '172.16.17.100'
      if synchedFolder
        override.vm.synced_folder "#{synchedFolder}", "/.provision" # equates to C:\.provision
      end
      (1..MAX_SERVER_TARGETS).each do |s|
        override.vm.provision 'shell', path: './automation/provisioning/addHOSTS.ps1', args: "172.16.17.10#{s} server-#{s}.sky.net"
      end
      override.vm.provision 'shell', path: './automation/provisioning/setenv.ps1', args: 'environmentDelivery VAGRANT Machine'
      override.vm.provision 'shell', path: './automation/provisioning/trustedHosts.ps1', args: '*'
      override.vm.provision 'shell', path: './automation/provisioning/CredSSP.ps1', args: 'client'
      override.vm.provision 'shell', path: './automation/provisioning/setenv.ps1', args: 'interactive yes User'
      override.vm.provision 'shell', path: './automation/provisioning/CDAF_Desktop_Certificate.ps1'
      override.vm.provision 'shell', path: './automation/provisioning/CDAF.ps1'
      override.vm.provision 'shell', path: './automation/provisioning/CDAF.ps1', args: '-OPT_ARG buildonly'
      override.vm.provision 'shell', path: './automation/provisioning/CDAF.ps1', args: '-OPT_ARG packageonly'
      override.vm.provision 'shell', path: './automation/provisioning/CDAF.ps1', args: '-OPT_ARG cionly'
      override.vm.provision 'shell', path: './automation/provisioning/CDAF.ps1', args: '-OPT_ARG cdonly'
    end
    
    # Microsoft Hyper-V does not support NAT or setting hostname. vagrant up build --provider hyperv
    build.vm.provider 'hyperv' do |hyperv, override|
      hyperv.vmname = "windows-build"
      hyperv.memory = "#{vRAM}"
      hyperv.cpus = "#{vCPU}"
      hyperv.ip_address_timeout = 300 # 5 minutes, default is 2 minutes (120 seconds)
      override.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: "#{ENV['VAGRANT_SMB_USER']}", smb_password: "#{ENV['VAGRANT_SMB_PASS']}"
    end
  end

end