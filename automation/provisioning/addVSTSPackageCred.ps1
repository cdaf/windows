Param (
  [string]$feedName,
  [string]$uri,
  [string]$feedPass,
  [string]$feedUser,
  [string]$nugetPath
)
$scriptName = 'addVSTSPackageCred.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
}

Write-Host "`n[$scriptName] Add VSTS Package Management credentials to allow non interactive authentication for NuGet."
Write-Host "`n[$scriptName] ---------- start ----------"
if ($feedName) {
    Write-Host "[$scriptName] feedName  : $feedName"
	$requiredParam += "-feedName $feedName "
} else {
    Write-Host "[$scriptName] feedName is required"; exit 100
}

if ($uri) {
    Write-Host "[$scriptName] uri       : $uri"
	$requiredParam += "-uri $uri "
} else {
    Write-Host "[$scriptName] uri is required"; exit 101
}

if ($feedPass) {
    Write-Host "[$scriptName] feedPass  : `$feedPass"
	$requiredParam += "-feedPass `$feedPass "
} else {
    Write-Host "[$scriptName] feedPass is required"; exit 102
}

if ($feedUser) {
    Write-Host "[$scriptName] feedUser  : $feedUser"
    $optParam += "-feedUser $feedUser "
} else {
	$feedUser = 'usingPAT'
    Write-Host "[$scriptName] feedUser  : $feedUser (default)"
}

if ($nugetPath) {
    Write-Host "[$scriptName] nugetPath : $nugetPath"
    $optParam += "-nugetPath $nugetPath "
} else {
	$nugetPath = 'C:/agent/externals/nuget/nuget.exe'
    Write-Host "[$scriptName] nugetPath : $nugetPath (default)"
}

# Provisionig Script builder
$scriptPath = [Environment]::GetEnvironmentVariable('PROV_SCRIPT_PATH', 'Machine')
if ( $scriptPath ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation-solution/provisioning/$scriptName $requiredParam $optParam`""
}

executeExpression "$nugetPath sources add -name $feedName -Source $uri -username $feedUser -password `$feedPass"

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0
