# The API Key needs to be obtained from the NuGet server to all package push without prompting for credentials
$PACK_LOC     = $args[0]
$API_KEY_FILE = $args[1]
$NUGET_URL    = $args[2]

$exitStatus = 0

$scriptName = $MyInvocation.MyCommand.Name
$userName = [Environment]::UserName

Write-Host " PACK_LOC     = $PACK_LOC"
Write-Host " API_KEY_FILE = $API_KEY_FILE"
Write-Host " NUGET_URL    = $NUGET_URL"

$secure = Get-Content $API_KEY_FILE | ConvertTo-SecureString
$plain = (New-Object System.Management.Automation.PSCredential 'N/A', $secure).GetNetworkCredential().Password

# Assumes the package location is cleaned and there will be only one eligable 
NuGet.exe push $PACK_LOC\*.nupkg -ApiKey $plain -Source $NUGET_URL
