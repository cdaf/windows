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
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
	if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "`n[$scriptName] Add VSTS Package Management credentials to allow non interactive authentication for NuGet."
Write-Host "`n[$scriptName] ---------- start ----------"
if ($feedName) {
    Write-Host "[$scriptName] feedName  : $feedName"
} else {
    Write-Host "[$scriptName] feedName is required"; exit 100
}

if ($uri) {
    Write-Host "[$scriptName] uri       : $uri"
} else {
    Write-Host "[$scriptName] uri is required"; exit 101
}

if ($feedPass) {
    Write-Host "[$scriptName] feedPass  : `$feedPass"
} else {
    Write-Host "[$scriptName] feedPass is required"; exit 102
}

if ($feedUser) {
    Write-Host "[$scriptName] feedUser  : $feedUser"
} else {
	$feedUser = 'usingPAT'
    Write-Host "[$scriptName] feedUser  : $feedUser (default)"
}

if ($nugetPath) {
    Write-Host "[$scriptName] nugetPath : $nugetPath"
} else {
	$nugetPath = 'C:/agent/externals/nuget/nuget.exe'
    Write-Host "[$scriptName] nugetPath : $nugetPath (default)"
}

Write-Host "[$scriptName] whoami    : $(whoami)"

Write-Host "`n[$scriptName] Add Source`n"
executeExpression "$nugetPath sources add -name $feedName -Source $uri -username $feedUser -password `$feedPass"

Write-Host "`n[$scriptName] List resulting sources`n"
executeExpression "$nugetPath sources"

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0
