Param (
  [string]$instanceName,
  [string]$port
)

# Reset $LASTEXITCODE
cmd /c "exit 0"
$Error.Clear()

$scriptName = 'sqlSetInstanceBind.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1112 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red ; $error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				$error
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName] `$error[] = $error"; exit 1113
		}
	}
}

function executeReturn ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		$result = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1112 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red ; $error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				$error
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName] `$error[] = $error"; exit 1113
		}
    }
    return $result
}


# from https://sqldbawithabeard.com/2015/04/22/instances-and-ports-with-powershell/
function GetSQLInstancesPort ($Server) { 
    [system.reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")|Out-Null
    [system.reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")|Out-Null
    $mc = new-object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $Server
    $Instances = $mc.ServerInstances
 
    foreach ($Instance in $Instances) {
        $port = @{Name = "Port"; Expression = {$_.ServerProtocols['Tcp'].IPAddresses['IPAll'].IPAddressProperties['TcpPort'].Value}}
        $Parent = @{Name = "Parent"; Expression = {$_.Parent.Name}}
        $Instance | Select $Parent, Name, $Port | Format-Table 
    }
}

# from https://www.sqlservercentral.com/Forums/Topic1434562-2799-1.aspx
Write-Host "`n[$scriptName] ---------- start ----------"
if ($instanceName) {
    Write-Host "[$scriptName] instanceName : $instanceName"
    $namedInstance = 'MSSQL$' + $instanceName
} else {
	$instanceName = 'MSSQLSERVER'
    Write-Host "[$scriptName] instanceName : $instanceName (not supplied, so default used)"
}

if ($port) {
    Write-Host "[$scriptName] port         : $port`n"
} else {
	$port = '1433'
    Write-Host "[$scriptName] port         : $port (not supplied, so default used)`n"
}

Write-Host "`n[$scriptName] List Instance details before"
GetSQLInstancesPort $env:computername

executeExpression '[system.reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")|Out-Null'
executeExpression '[system.reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")|Out-Null'

$MachineObject = executeExpression "new-object ('Microsoft.SqlServer.Management.Smo.WMI.ManagedComputer') ."
$ProtocolUri = "ManagedComputer[@Name='" + (get-item env:\computername).Value + "']/ServerInstance[@Name='$instanceName']/ServerProtocol"

$tcp = executeReturn "`$MachineObject.getsmoobject(`$ProtocolUri + `"[@Name='Tcp']`")"
executeExpression "`$MachineObject.getsmoobject(`$tcp.urn.Value + `"/IPAddress[@Name='IPAll']`").IPAddressProperties[1].Value = `"$port`""
executeExpression '$tcp.IsEnabled = $true'
executeExpression '$tcp.alter()'

Write-Host "`n[$scriptName] List Instance details after"
GetSQLInstancesPort $env:computername

Write-Host "[$scriptName] Restart SQL Service to apply change`n"
if ( $namedInstance ) {
	Write-Verbose "Starting SQL Server (named instance $namedInstance)"
	executeExpression "Restart-Service '$namedInstance'"
} else {
	Write-Verbose "Starting SQL Server (default instance $instanceName)"
	executeExpression "Restart-Service '$instanceName'"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
