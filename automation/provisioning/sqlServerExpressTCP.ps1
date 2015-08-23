# Load the assemblies
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")

$action = $args[0]

# Action is optional, if passed, override the enablement
if ($action) {
    $enableTCP = $false
} else {
    $enableTCP = $true
}
$smo = 'Microsoft.SqlServer.Management.Smo.'
$wmi = new-object ($smo + 'Wmi.ManagedComputer').

# List the object properties, including the instance names and prepare the connection string
$Wmi
$computerName = $wmi.Urn
$uri = "$computerName/ServerInstance[@Name='SQLEXPRESS']/ServerProtocol[@Name='Tcp']"
Write-Host "uri = $uri"

# Enable the TCP protocol on the default instance.
$Tcp = $wmi.GetSmoObject($uri)
$Tcp.IsEnabled = $enableTCP
$Tcp.Alter()
$Tcp

# Enable the named pipes protocol for the default instance.
$uri = $computerName + "/ServerInstance[@Name='SQLEXPRESS']/ServerProtocol[@Name='Np']"
$Np = $wmi.GetSmoObject($uri)
$Np.IsEnabled = $enableTCP
$Np.Alter()
$Np
