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

# Adjust for the number of target servers desired (delivery)
# [Environment]::SetEnvironmentVariable('MAX_SERVER_TARGETS', '3', 'User')
if ENV['MAX_SERVER_TARGETS']
  puts "Deploy targets (MAX_SERVER_TARGETS) = #{ENV['MAX_SERVER_TARGETS']}" 
  MAX_SERVER_TARGETS = ENV['MAX_SERVER_TARGETS'].to_i
else
  MAX_SERVER_TARGETS = 1
end

# If this environment variable is set, then the location defined will be used for media
# [Environment]::SetEnvironmentVariable('SYNCED_FOLDER', '/opt/.provision', 'Machine')
if ENV['SYNCED_FOLDER']
  synchedFolder = ENV['SYNCED_FOLDER']
end

Vagrant.configure(2) do |config|

  # Build Server connects to this host to perform deployment
  (1..MAX_SERVER_TARGETS).each do |i|
    config.vm.define "server-#{i}" do |server|
      server.vm.box = 'cdaf/WindowsServerStandard'

      server.vm.provision 'shell', path: './automation/remote/capabilities.ps1'
      server.vm.provision 'shell', path: './automation/provisioning/mkdir.ps1', args: 'C:\deploy'
  
      # Oracle VirtualBox with private NAT, not setting hostname due to https://github.com/hashicorp/vagrant/issues/10229
      server.vm.provider 'virtualbox' do |virtualbox, override|
        virtualbox.memory = "#{vRAM}"
        virtualbox.cpus = "#{vCPU}"
        override.vm.network 'private_network', ip: "172.16.17.10#{i}"
        (1..MAX_SERVER_TARGETS).each do |s|
          server.vm.provision 'shell', path: './automation/provisioning/addHOSTS.ps1', args: "172.16.17.10#{s} server-#{s}.sky.net"
        end
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
        if ENV['VAGRANT_SMB_USER']
          override.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: "#{ENV['VAGRANT_SMB_USER']}", smb_password: "#{ENV['VAGRANT_SMB_PASS']}"
        end
      end
    end
  end

  # Build Server, fills the role of the build agent and delivers to the host above
  config.vm.define 'build' do |build|
    build.vm.box = 'cdaf/WindowsServerStandard'
    build.vm.provision 'shell', path: './automation/remote/capabilities.ps1'
    
    # Oracle VirtualBox with private NAT has insecure deployer keys for desktop testing
    build.vm.provider 'virtualbox' do |virtualbox, override|
      virtualbox.name = 'windows-build'
      virtualbox.memory = "#{vRAM}"
      virtualbox.cpus = "#{vCPU}"
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
    end
    
    # Microsoft Hyper-V does not support NAT or setting hostname. vagrant up build --provider hyperv
    build.vm.provider 'hyperv' do |hyperv, override|
      hyperv.vmname = "windows-build"
      hyperv.memory = "#{vRAM}"
      hyperv.cpus = "#{vCPU}"
      if ENV['VAGRANT_SMB_USER']
        override.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: "#{ENV['VAGRANT_SMB_USER']}", smb_password: "#{ENV['VAGRANT_SMB_PASS']}"
      end
    end
  end

end