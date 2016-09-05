function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
}

# The API Key needs to be obtained from the NuGet server to all package push without prompting for credentials
$PACK_LOC     = $args[0]
$API_KEY_FILE = $args[1]
$NUGET_URL    = $args[2]

$scriptName = 'push.ps1'

Write-Host "[$scriptName] PACK_LOC     : $PACK_LOC"
Write-Host "[$scriptName] API_KEY_FILE : $API_KEY_FILE"
Write-Host "[$scriptName] NUGET_URL    : $NUGET_URL"

$secure = Get-Content $API_KEY_FILE | ConvertTo-SecureString
$plain = (New-Object System.Management.Automation.PSCredential 'N/A', $secure).GetNetworkCredential().Password

# Assumes the package location is cleaned and there will be only one eligable 
executeExpression "NuGet.exe push $PACK_LOC\*.nupkg -ApiKey `$plain -Source $NUGET_URL"
