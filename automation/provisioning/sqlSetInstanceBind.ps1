Param (
  [string]$instanceName,
  [string]$port
)

# Reset $LASTEXITCODE
cmd /c exit 0

$scriptName = 'sqlSetInstanceBind.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
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
    Write-Host "[$scriptName] port         : $port"
} else {
	$port = '1433'
    Write-Host "[$scriptName] port         : $port (not supplied, so default used)"
}

executeExpression '[system.reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")|Out-Null'
executeExpression '[system.reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")|Out-Null'

$MachineObject = executeExpression "new-object ('Microsoft.SqlServer.Management.Smo.WMI.ManagedComputer') ."
$ProtocolUri = "ManagedComputer[@Name='" + (get-item env:\computername).Value + "']/ServerInstance[@Name='$instanceName']/ServerProtocol"

$tcp = executeExpression "`$MachineObject.getsmoobject(`$ProtocolUri + `"[@Name='Tcp']`")"
executeExpression "`$MachineObject.getsmoobject(`$tcp.urn.Value + `"/IPAddress[@Name='IPAll']`").IPAddressProperties[1].Value = `"$port`""
executeExpression '$tcp.alter()'

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
