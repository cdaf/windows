# Load the assemblies
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")

$DBServer = $args[0]
$Instance = $args[1]
$dbName = $args[2]

$db = New-Object Microsoft.SqlServer.Management.SMO.Database
$db.Parent = Get-Item "SQLSERVER:\SQL\$DBServer\$Instance"
$db.Name = $dbName
$db.Create()
