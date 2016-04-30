# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

# Zip Package creation requires PowerShell v3 or above and .NET 4.5 or above.

Vagrant.configure(2) do |allhosts|

  allhosts.vm.define 'app' do |app|
   app.vm.communicator = 'winrm'
    # Oracle VirtualBox
    app.vm.provider 'virtualbox' do |virtualbox, override|
      override.vm.hostname = 'app'
      override.vm.box = 'opentable/win-2012r2-standard-amd64-nocm'
      override.vm.network 'private_network', ip: '172.16.17.101'
      override.vm.network 'forwarded_port', host: 13389, guest: 3389 # Remote Desktop
      override.vm.network 'forwarded_port', host: 15985, guest: 5985 # WinRM HTTP
      override.vm.network 'forwarded_port', host: 13986, guest: 5986 # WinRM HTTPS
      override.vm.network 'forwarded_port', host: 10080, guest:   80
      override.vm.network 'forwarded_port', host: 10443, guest:  443
      override.vm.provision 'shell', path: './automation/provisioning/CredSSP.ps1'
      override.vm.provision 'shell', path: './automation/provisioning/mkdir.ps1', args: 'C:\deploy'
    end
    # Microsoft Hyper-V does not support NAT or setting hostname. vagrant up app --provider hyperv
    app.vm.provider 'hyperv' do |hyperv, override|
      override.vm.box = 'mwrock/Windows2012R2'
      override.vm.provision 'shell', path: './automation/provisioning/mkdir.ps1', args: 'C:\deploy'
    end
  end

  allhosts.vm.define 'buildserver' do |buildserver|
    buildserver.vm.communicator = 'winrm'
    # Oracle VirtualBox
    buildserver.vm.provider 'virtualbox' do |virtualbox, override|
      override.vm.box = 'opentable/win-2012r2-standard-amd64-nocm'
      override.vm.network 'private_network', ip: '172.16.17.102'
      override.vm.network 'forwarded_port', host: 23389, guest: 3389 # Remote Desktop
      override.vm.network 'forwarded_port', host: 25985, guest: 5985 # WinRM HTTP
      override.vm.network 'forwarded_port', host: 25986, guest: 5986 # WinRM HTTPS
      override.vm.provision 'shell', path: './automation/provisioning/Capabilities.ps1'
      override.vm.provision 'shell', path: './automation/provisioning/setenv.ps1', args: 'environmentDelivery VAGRANT Machine'
      override.vm.provision 'shell', path: './automation/provisioning/CDAF_Desktop_Certificate.ps1'
      override.vm.provision 'shell', path: './automation/provisioning/trustedHosts.ps1', args: '172.16.17.101'
      override.vm.provision 'shell', path: './automation/provisioning/CredSSP.ps1'
      override.vm.provision 'shell', path: './automation/provisioning/Capabilities.ps1'
      override.vm.provision 'shell', path: './automation/provisioning/CDAF.ps1'
    end
    # Microsoft Hyper-V does not support NAT or setting hostname. vagrant up buildserver --provider hyperv
    buildserver.vm.provider 'hyperv' do |hyperv, override|
      override.vm.box = 'mwrock/Windows2012R2'
    end
  end

end