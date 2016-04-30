# Enable Powershell remoting on server
#
[String]$confirm = read-host "Enter 'Y' to setup Powershell Remoting on this Server"

if ($confirm.ToLower() -eq "y")
{
	Enable-PSRemoting -force

	# ensure that there is enough memory available to the remote shell to run the deployment scripts
	Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 1000
}


# Enable Server to access remote resource using the credentials of the connecting user
#
# see here for more details 
# http://rkeithhill.wordpress.com/2009/05/02/powershell-v2-remoting-on-workgroup-joined-computers-%E2%80%93-yes-it-can-be-done/

[String]$confirm = read-host "Enter 'Y' to setup CredSSP, CredSSP allows commands run on this server to access networked resources"

if ($confirm.ToLower() -eq "y")
{
	Enable-WSManCredSSP –Role Server
}
