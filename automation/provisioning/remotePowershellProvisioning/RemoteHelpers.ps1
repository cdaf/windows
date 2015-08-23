<#
.SYNOPSIS
Open a remote Powershell session to the specified server.

.DESCRIPTION
Wrapper for new-pssession.

.PARAMETER sessionName
Name of the session, used in subsequent remote session requests.

.PARAMETER targetServer
Name of the target server, can be DNS, FQDN or IP address.

.PARAMETER username
Username of session to connect with, or leave empty to connect as the current user

.PARAMETER password
Password of given user.

.PARAMETER authentication
Optional, defaults to 'Default', used to override the default behaviour to support CredSSP, which is require to support second hop remoting.

.EXAMPLE
OpenSession WebServer $targetWebServer $remoteUser $remotePassword.

.EXAMPLE
OpenSession WebServer $targetWebServer $remoteUser $remotePassword CredSSP

.NOTES
Multiple remote session may be created at the same time.
Use CloseSession() to close a session.
#>
function OpenSession(
	[string]$sessionName,
	[string]$targetServer,
	[string]$username = '',
	[string]$password = '',
	[string]$authentication = "Default")
{                   
    if (($error.count -gt 0) -and ($global:ignoreRemoteCommandsOnError -eq $true))
    {
		write-host "OpenSession: Ignored due to earlier error: " $sessionName
		return
    }
 
    write-host "OpenSession: " $sessionName
          
    if ($username -ne '')
    {
		write-host "Connecting with Username = " $username ", Authentication = " $authentication
		$securePassword = ConvertTo-SecureString -AsPlainText -Force -String $password
		$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $securePassword
            
		new-pssession $targetServer -credential @credential -Authentication $authentication -name $sessionName
    }
    else
    {
		write-host "Connecting as the current user, with Default authentication"
		new-pssession $targetServer -Authentication Default -name $sessionName            
    }                   
}

<#
.SYNOPSIS
Close the named remote Powershell session

.DESCRIPTION
Wrapper for remove-pssession

.PARAMETER sessionName
Name of the session to close

.EXAMPLE
Example 1: CloseSession WebServer
#>       
function CloseSession(
	[string]$sessionName)
{
    $session = get-pssession |  where {($_.Name -like $sessionName)}
          
    if ($session -eq $null )
    {
		write-host "CloseSession: Ignored as session does not exist: " $sessionName
		return
    }
 
    write-host "CloseSession: " $sessionName
    remove-pssession -name $sessionName
}    

<#
.SYNOPSIS
Run a remote powershell command in the specified session

.DESCRIPTION
Wrapper for InvokeCommand with error management

.PARAMETER sessionName
Name of the session to use

.PARAMETER command
Powershell command to run

.PARAMETER workingFolder
Folder on remote server to run command in

.EXAMPLE
RemoteCommand WebServer ".\Maintenance.bat /t:StopAppPools Websites.proj" "c:\Releases\WebServerPackage"

.NOTES
When using the remote command be mindful of difference between " and ' quotes in the evalulation of variables.
i.e. "$myVariable" will pass the value of myVariable, where as '$myVariable' will pass $myVariable as a string.
#>        
function RemoteCommand(
    [string]$sessionName,
    [string]$command,
    [string]$workingFolder,
	[bool]$rethrowErrors = $true)
{           
    write-host "RemoteCommand: " $command $rethrowErrors
    $session = Get-PSSession -name $sessionName
	$errorCount = $error.count

    if ($workingFolder -ne $null)
    {
		$scriptBlock = $executioncontext.InvokeCommand.NewScriptBlock("cd $workingFolder;")
		invoke-command -session $session $scriptBlock
    }

	$scriptBlock = $executioncontext.InvokeCommand.NewScriptBlock($command)
	invoke-command -session $session $scriptBlock

    $LastExitCode = invoke-command -session $session {$LASTEXITCODE}

	if ($LastExitCode -ne 0 -and $LastExitCode -ne $null -and $rethrowErrors -eq $true)
    {
        throw 'Remote Batch LastExitCode not 0'      
    }  
	if ($error.count -gt $errorCount -and $rethrowErrors -eq $true) 
	{
		throw $error[0].Exception
	}             
}          

<#
.SYNOPSIS
Perform an unzip on a remote server

.DESCRIPTION
Wrapper for for shell functions to perform and unzip

.PARAMETER sessionName
Name of the session to use

.PARAMETER zipFilePath
full path (on the remote server) of the zip file

.PARAMETER destinationPath
full path (on the remote server) of the folder to expand the zip file in to

.EXAMPLE
RemoteUnzip WebServer "c:\Releases\$buildNumber-WebServer.zip" "c:\Releases\WebServerPackage"
#>               
function RemoteUnzip(
	[string]$sessionName,
    [string]$zipFilePath,
    [string]$destinationPath,
	[bool]$rethrowErrors = $true)
{
    write-host "RemoteUnzip: " $zipFilePath
	$errorCount = $error.count
	          
    $session = Get-PSSession -name $sessionName
    $result = invoke-command `
        -session $session `
        -argumentlist $zipFilePath, $destinationPath `
        -scriptblock {
        param($zipFilePath, $destinationPath)
               
            mkdir $destinationPath -force
                  
            $shell_app=new-object -com shell.application 
            $filename = "$zipFilePath" 
            $zip_file = $shell_app.namespace("$zipFilePath") 
            $destination = $shell_app.namespace($destinationPath) 
            $destination.Copyhere($zip_file.items(), 0x14)                  
        }

	if ($error.count -gt $errorCount -and $rethrowErrors -eq $true) 
	{
		throw $error[0].Exception
	}             
}   

<#
.SYNOPSIS
Delete and optionally Backup a files or folders on a remote server

.DESCRIPTION
Wrapper for shell functions to perform:
 - mv of source path into destination folder (if specified)
 - del of source path if no destination

.PARAMETER sessionName
Name of the session to use

.PARAMETER path
Path to delete/backup

.PARAMETER backupFolder
Optional desitination folder to move source path into

.PARAMETER backupPath
Optional desitination path to copy source path into

.EXAMPLE
RemoteDeletePath WebServer "c:\Releases\WebServerPackage" "c:\Releases\PreviousRelease"
#>        
function RemoteDeletePath(
    [string]$sessionName,
    [string]$path,
    [string]$backupFolder = '',
    [string]$backupPath = '',
	[bool]$rethrowErrors = $true)
{           
    write-host "RemoteDeletePath: " $path $backupFolder $backupPath
    $session = Get-PSSession -name $sessionName
	$errorCount = $error.count
   
	$result = invoke-command `
        -session $session `
        -argumentlist $path, $backupFolder, $backupPath `
        -scriptblock {
        param($path, $backupFolder, $backupPath)
                           
			if ("$backupFolder" -ne '')
			{
                # Create folder if it does not exist
				mkdir "$backupFolder" -force
                
                # Ensure backup folder is empty
                del "$backupFolder\*" -recurse -force
                
                # backup the files
                if (test-path "$path")
                {
				    mv -path "$path" -destination "$backupfolder" -force
                }
			}
            elseif ("$backupPath" -ne '')
			{
                # Delete previous backup
                if (test-path "$backupPath")
                {
				    del "$backupPath" -recurse -force
                }
                                
                # backup the files
                if (test-path "$path")
                {
                    mv -path "$path" -destination "$backupPath" -force
                }                
			}
            else
            {
                # No Backup so just remove the files in the path
                if (test-path "$path")
                {
                    del -path "$path" -recurse -force
                }
            }
        }

	if ($error.count -gt $errorCount -and $rethrowErrors -eq $true) 
	{
		throw $error[0].Exception
	}             
}   


function Get-FilenameRelativeToScript([string]$fileName)
{
	return Join-Path (Get-ScriptDirectory) $fileName
}

function Get-ScriptDirectory 
{ 
	$Invocation = (Get-Variable MyInvocation -Scope script).Value 
	Split-Path $Invocation.MyCommand.Path 
} 
