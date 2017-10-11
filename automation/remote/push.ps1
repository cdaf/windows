function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
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
