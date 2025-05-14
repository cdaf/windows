# Enable Powershell remoting on server
#
[String]$confirm = read-host "Enter 'Y' to setup Powershell Remoting on this Server"

if ($confirm.ToLower() -eq "y")
{
	Enable-PSRemoting -force

	#Clients also require that the TrustedHosts be configured
	Write-host "Enter TrustedHosts: Comma delimited list of hosts, * can be used as a wildcard."
	[String]$hostList = read-host "TrustedHosts"
	Set-Item -force WSMan:\localhost\Client\TrustedHosts $hostList

	restart-Service winrm
}


# Enable client to delegate credentials to the a server 
#
# see here for more details 
# http://rkeithhill.wordpress.com/2009/05/02/powershell-v2-remoting-on-workgroup-joined-computers-%E2%80%93-yes-it-can-be-done/

[String]$confirm = read-host "Enter 'Y' to setup CredSSP, CredSSP allows commands run from this client to access networked resources"

if ($confirm.ToLower() -eq "y")
{
	[String]$delgatedComputer = read-host "CredSSP setup, Enter computer to delagate control (either hostname or FQDN):"

	if ($delgatedComputer -ne "")
	{
		Enable-WSManCredSSP –Role Client –DelegateComputer $delgatedComputer


		Write-warning ""
		Write-warning "To Complete setup a tweak is required via the global policy editor."
		Write-warning "Run gpedit.msc and navigate to Computer Configuration –> Administrative Templates –> System –> Credential Delegation"
		Write-warning "Enable the 'Allow Delegating Fresh Credentials' setting"
		Write-warning "..then click on the Show… button to add a server to the list, in the form wsman/<domain>"
		Write-warning "repeat for the 'Allow Fresh Credentials with NTLM-only Server Authentication' setting"
		Write-warning ""
		Write-host "Note that tho use delgation the remote powershell sessions must use CredSSP authentication"


		[String]$confirm = read-host "Enter 'Y' to start gpedit"
		if ($confirm.ToLower() -eq "y")
		{
			gpedit.msc
		}
	}
}