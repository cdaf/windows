Param (
  [string]$app,
  [string]$physicalPath,
  [string]$site,
  [string]$appPool,
  [string]$clrVersion
)
$scriptName = 'IISAddApp.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	$LASTEXITCODE = 0
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 10 }
	} catch { echo $_.Exception|format-list -force; exit 11 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 12 }
    if ( $LASTEXITCODE -ne 0 ) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($app) {
    Write-Host "[$scriptName] app          : $app"
    $argList = "$app"
} else {
    Write-Host "[$scriptName] app no supplied"
    exit 100
}

if ($physicalPath) {
    Write-Host "[$scriptName] physicalPath : $physicalPath"
} else {
	$physicalPath = 'c:\inetpub\' + $app
    Write-Host "[$scriptName] physicalPath : $physicalPath (default)"
}
$argList += " $physicalPath"

if ($site) {
    Write-Host "[$scriptName] site         : $site"
} else {
	$site = 'Default Web Site'
    Write-Host "[$scriptName] site         : $site (default)"
}
$argList += " $site"

if ($appPool) {
    Write-Host "[$scriptName] appPool      : $appPool "
	$argList += " $appPool"
} else {
    Write-Host "[$scriptName] appPool      : (not supplied, will use DefaultAppPool if site needs to be created)"
}

if ($clrVersion) {
    Write-Host "[$scriptName] clrVersion   : $clrVersion (set to NoManagedCode for no CLR version)"
	$argList += " $clrVersion"
} else {
    Write-Host "[$scriptName] clrVersion   : (not supplied, set to NoManagedCode for no CLR version)"
}
# Provisioning Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $argList`""
}
Write-Host

if (Test-Path "$physicalPath") {
    Write-Host "[$scriptName] Physical path $physicalPath exists, no action required."
} else {
	$newDir = executeExpression "New-Item -ItemType Directory -Force -Path `'$physicalPath`'"
	Write-Host "Created $($newDir.FullName)"
}

Write-Host
executeExpression 'import-module WebAdministration'

if ($appPool) {
	if (Test-Path "IIS:\AppPools\$appPool") {
	    Write-Host "[$scriptName] Application Pool $appPool exists"
	} else {
		executeExpression "New-Item `'IIS:\AppPools\$appPool`'"
	}
}

if (Test-Path "IIS:\Sites\$site\$app") {
    Write-Host "[$scriptName] Site IIS:\Sites\$site\$app exists"
	if ($appPool) {
		executeExpression "Set-ItemProperty `'IIS:\Sites\$site\$app`' -name `'$app`' -value `'$appPool`'"
	}
} else {
	if ($appPool) {
		executeExpression "New-WebApplication -Site `'$site`' -name `'$app`' -PhysicalPath `'$physicalPath`' -ApplicationPool `'$appPool`'"
	} else {
		executeExpression "New-WebApplication -Site `'$site`' -name `'$app`' -PhysicalPath `'$physicalPath`' -ApplicationPool `'DefaultAppPool`'"
	}
}

if ($clrVersion) {
	if ($clrVersion -like "NoManagedCode") {
		executeExpression "Set-ItemProperty `'IIS:\AppPools\$appPool`' managedRuntimeVersion `'`' "
	} else {
		executeExpression "Set-ItemProperty `'IIS:\AppPools\$appPool`' managedRuntimeVersion `'$clrVersion`'"
	}
}

Write-Host "`n[$scriptName] List application pool version`n"
foreach ($pool in Get-Item "IIS:\AppPools\*") {
	$poolName = $($pool).name
	Write-Host "  $poolName : $((Get-ItemProperty IIS:\AppPools\$poolName managedRuntimeVersion).value)"
}

Write-Host "`n[$scriptName] List application pool state`n"
executeExpression "Format-Table -InputObject (Get-Item 'IIS:\AppPools\*')"

Write-Host "`n[$scriptName] List Sites and Apps`n"
foreach ($site in Get-Item "IIS:\Sites\*") {
	$siteName = $($site).name
	Write-Host "  $siteName : $((Get-Item IIS:\Sites\$siteName\*).Path)"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
