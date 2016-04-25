param ([string] $instance, [string] $collation, $ServiceAccountPassword, $saPassword, $sourceDir, $servicePackExec, $instDrive, $userDbDrive, $userLogDrive, $tempDbDrive,  $tempLogDrive, $backupDrive , $port )


###############################
# install prerequisites for SQL2008R2
function installPrereqs () {
	Import-Module ServerManager
	Add-WindowsFeature Application-Server,AS-NET-Framework,NET-Framework,NET-Framework-Core,WAS,WAS-Process-Model,WAS-NET-Environment,WAS-Config-APIs
	# get-windowsfeature | Where {$_.Installed} | Sort FeatureType,Parent,Name | Select Name,Displayname,FeatureType,Parent
}

###############################
# change the TCP port at the end of the installation
function changePort ($SQLName , $Instance, $port) {
    Try
        {
 
	$SQLName
	$Instance

	# Load SMO Wmi.ManagedComputer assembly
	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | out-null
	
	Trap {
		$err = $_.Exception
		while ( $err.InnerException ) {
			$err = $err.InnerException
			write-output $err.Message
		}
		continue
	}

	# Connect to the instance using SMO
	$m = New-Object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer') $SQLName
	$urn = "ManagedComputer[@Name='$SQLName']/ServerInstance[@Name='$Instance']/ServerProtocol[@Name='Tcp']"
	$Tcp = $m.GetSmoObject($urn)
	$Enabled = $Tcp.IsEnabled
	#Enable TCP/IP if not enabled
	IF (!$Enabled)
	    {$Tcp.IsEnabled = $true }
	
	#Set to listen on 1433 and disable dynamic ports
	$m.GetSmoObject($urn + "/IPAddress[@Name='IPAll']").IPAddressProperties[1].Value = $port
	$m.GetSmoObject($urn + "/IPAddress[@Name='IPAll']").IPAddressProperties['TcpDynamicPorts'].Value = ''
	$TCP.alter()
 
        "Success: SQL set to listen on TCP/IP port $port. Please restart the SQL service for changes to take effect."
    }
    Catch { Write-Warning "Unable to enable TCP/IP & set SQL to listen on port $port" }
} 

#########################################
# prepare the standard configuration file
function prepareConfigFile ([String]$instance, [String]$collation, $instDrive, $userDbDrive, $userLogDrive, $tempDbDrive, $tempLogDrive, $backupDrive ) {
$config = "[SQLSERVER2008]
ACTION=""Install""
FEATURES=SQLENGINE,REPLICATION,FULLTEXT,BIDS,CONN,IS,BC,BOL,SSMS,ADV_SSMS,SNAC_SDK
INSTANCENAME=""$instance""
INSTANCEID=""$instance""
INSTALLSHAREDDIR=""C:\Program Files\Microsoft SQL Server""
INSTALLSHAREDWOWDIR=""C:\Program Files (x86)\Microsoft SQL Server""
INSTANCEDIR=""C:\Program Files\Microsoft SQL Server""
INSTALLSQLDATADIR="""+$instDrive+":\MSSQL\$instance""
SQLUSERDBDIR="""+$userDbDrive+":\MSSQL\$instance\MSSQL10_50."+$instance+"\MSSQL\Data""
SQLUSERDBLOGDIR="""+$userLogDrive+":\MSSQL\$instance\MSSQL10_50."+$instance+"\MSSQL\Tlog""
SQLTEMPDBDIR="""+$tempDbDrive+":\MSSQL\$instance\MSSQL10_50."+$instance+"\MSSQL\Data""
SQLTEMPDBLOGDIR="""+$tempLogDrive+":\MSSQL\$instance\MSSQL10_50."+$instance+"\MSSQL\Tlog""
SQLBACKUPDIR="""+$backupDrive+":\MSSQL\$instance\MSSQL10_50."+$instance+"\MSSQL\Backup""
FILESTREAMLEVEL=""0""
TCPENABLED=""1""
NPENABLED=""1""
SQLCOLLATION=""$collation""
SQLSVCACCOUNT=""MYDOM\sqlsrvc""
SQLSVCSTARTUPTYPE=""Automatic""
AGTSVCACCOUNT=""MYDOM\sqlsrvc""
AGTSVCSTARTUPTYPE=""Automatic""
ISSVCACCOUNT=""NT AUTHORITY\NetworkService""
ISSVCSTARTUPTYPE=""Automatic""
BROWSERSVCSTARTUPTYPE=""Automatic""
SQLSYSADMINACCOUNTS=""MYDOM\sqlsrvc""
SECURITYMODE=""SQL""
SQMREPORTING=""False""
IACCEPTSQLSERVERLICENSETERMS=""True"""

$config
}

function displayDrives () {
	Get-WmiObject -class "Win32_LogicalDisk" | ?{ @(2, 3) -contains $_.DriveType } | where {$_.Freespace} | select Name, VolumeName, Size, FreeSpace
}


##     ##    ###    #### ##    ## 
###   ###   ## ##    ##  ###   ## 
#### ####  ##   ##   ##  ####  ## 
## ### ## ##     ##  ##  ## ## ## 
##     ## #########  ##  ##  #### 
##     ## ##     ##  ##  ##   ### 
##     ## ##     ## #### ##    ##

######################
# Getting Parameters #
######################
if ( -not $sourceDir) { $sourceDir = Read-Host 'Source Path containing SQL2008R2 installation ? ' }
if ( -not $servicePackExec) { $servicePackExec = Read-Host 'Full Path to service pack executable [Empty for None]? ' }
if ( -not $instance) { $instance = Read-Host 'Instance Name? ' }
if ( -not $collation ) {$collation = Read-Host 'Collation [Latin1_General_CI_AS]? ' }
if ( -not $collation ) { $collation = "Latin1_General_CI_AS" }


if ( -not $port ) { $port = Read-Host 'TCP Port [1433]? ' }
if ( -not $port ) { $port = "1433" }

if ( -not $ServiceAccountPassword ) { 
	[System.Security.SecureString]$ServiceAccountPassword = Read-Host "Enter the service account password: " -AsSecureString; 
	[String]$syncSvcAccountPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ServiceAccountPassword)); 
} else { [String]$syncSvcAccountPassword = $ServiceAccountPassword; } 

if ( -not $saPassword ) { 
	[System.Security.SecureString]$saPasswordSec = Read-Host "Enter the sa password: " -AsSecureString; 
	[String]$saPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($saPasswordSec)); 
} else { [String]$saPassword = $ServiceAccountPassword; } 


$instance = $instance.ToUpper()
$environ = $instance.Substring($instance.length-1)

########################
# Getting Disk Letters #
########################

$driveDisplayed=0

if ( -not $instDrive ) {
	if ( $driveDisplayed -eq 0 ) { displayDrives ; $driveDisplayed=1 }
	$instDrive = Read-Host 'Drive letter (without colon) for Instance Installation? ' 
}

if ( -not $userDbDrive ) {
	if ( $driveDisplayed -eq 0 ) { displayDrives ; $driveDisplayed=1 }
	$userDbDrive = Read-Host 'Drive letter (without colon) for User Databases? ' 
}

if ( -not $userLogDrive ) {
	if ( $driveDisplayed -eq 0 ) { displayDrives ; $driveDisplayed=1 }
	$userLogDrive = Read-Host 'Drive letter (without colon) for Transaction Logs ? ' 
}

if ( -not $tempDbDrive ) {
	if ( $driveDisplayed -eq 0 ) { displayDrives ; $driveDisplayed=1 }
	$tempDbDrive = Read-Host 'Drive letter (without colon) for Temp Database ? ' 
}

if ( -not $tempLogDrive ) {
	if ( $driveDisplayed -eq 0 ) { displayDrives ; $driveDisplayed=1 }
	$tempLogDrive = Read-Host 'Drive letter (without colon) for Temp Logs ? ' 
}

if ( -not $backupDrive ) {
	if ( $driveDisplayed -eq 0 ) { displayDrives ; $driveDisplayed=1 }
	$backupDrive = Read-Host 'Drive letter (without colon) for Backups ? ' 
}


$hostName = get-content env:computername

#####################
# Creating Ini File #
#####################
$workDir = pwd

"Creating Ini File for Installation..."
$configFile = "$workDir\sql2008_"+$instance+"_install.ini"

prepareConfigFile $instance $collation $instDrive $userDbDrive $userLogDrive $tempDbDrive $tempLogDrive $backupDrive | Out-File $configFile

"Configuration File written to: "+$configFile

######################
# Installing Prereqs #
######################
"Installing Prerequisites (.Net, etc) ..."
installPrereqs 

#######################################
# Starting SQL 2008 Base Installation #
#######################################

set-location $sourceDir

"Starting SQL 2008 Base Installation..."
$installCmd = ".\setup.exe /qs /SQLSVCPASSWORD=""$syncSvcAccountPassword"" /AGTSVCPASSWORD=""$syncSvcAccountPassword"" /SAPWD=""$saPassword"" /ConfigurationFile=""$configFile"""

Invoke-Expression $installCmd


set-location $workDir

#######################################
# Starting SQL 2008 SP Installation #
#######################################
if ( $servicePackExec) {
	"Starting Service Pack Installation..."
	$patchCmd = "$servicePackExec /Action=Patch /Quiet /IAcceptSQLServerLicenseTerms /Instancename=""$Instance"""
	$patchCmd
	Invoke-Expression $patchCmd

	## have to take the name of the process and wait for the completion of the pid because service packs
	## return prompt immediately and then run in background
	$process=[System.IO.Path]::GetFileNameWithoutExtension($servicePackExec)
	$nid = (Get-Process $process).id
	Wait-Process -id $nid
}

####################
# Changing TCPport #
####################

"Changing TCP port to $port..."
changePort $hostName $instance $port

## add required snap-in to query sqlserver
if ( (Get-PSSnapin -Name sqlserverprovidersnapin100 -ErrorAction SilentlyContinue) -eq $null ) {
    Add-PsSnapin sqlserverprovidersnapin100 
}
if ( (Get-PSSnapin -Name sqlservercmdletsnapin100 -ErrorAction SilentlyContinue) -eq $null ) {
    Add-PsSnapin sqlservercmdletsnapin100
}

###############################
# Resizing / Adding Tempfiles #
###############################

$Connection = New-Object System.Data.SQLClient.SQLConnection
$hostName = get-content env:computername

$Connection.ConnectionString ="Server=$hostName\$instance;Database=master;uid=sa;Pwd=$saPassword;"
$Connection.Open()

$Command = New-Object System.Data.SQLClient.SQLCommand
$Command.Connection = $Connection

$Command.CommandText = "ALTER DATABASE tempdb MODIFY FILE (NAME = tempdev, SIZE = 1024MB, filegrowth = 64MB, maxsize=unlimited);"
$Command.ExecuteNonQuery() | out-null
$Command.CommandText = "ALTER DATABASE tempdb MODIFY FILE (NAME = templog, SIZE = 512MB, filegrowth = 64MB, maxsize=unlimited);"
$Command.ExecuteNonQuery() | out-null

$Command.CommandText = "ALTER DATABASE tempdb ADD FILE (NAME = tempdev2, FILENAME = '"+$tempDrive+":\MSSQL\$instance\MSSQL10_50.$instance\MSSQL\Data\tempdb2.ndf', SIZE = 1024MB, filegrowth = 64MB, maxsize=unlimited);"
$Command.ExecuteNonQuery() | out-null
$Command.CommandText = "ALTER DATABASE tempdb ADD FILE (NAME = tempdev3, FILENAME = '"+$tempDrive+":\MSSQL\$instance\MSSQL10_50.$instance\MSSQL\Data\tempdb3.ndf', SIZE = 1024MB, filegrowth = 64MB, maxsize=unlimited);"
$Command.ExecuteNonQuery() | out-null
$Command.CommandText = "ALTER DATABASE tempdb ADD FILE (NAME = tempdev4, FILENAME = '"+$tempDrive+":\MSSQL\$instance\MSSQL10_50.$instance\MSSQL\Data\tempdb4.ndf', SIZE = 1024MB, filegrowth = 64MB, maxsize=unlimited);"
$Command.ExecuteNonQuery() | out-null

$Connection.Close()
