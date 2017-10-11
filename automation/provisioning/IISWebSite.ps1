Param (
  [string]$webSite,
  [string]$bindingProtocol,
  [string]$bindingInformation,
  [string]$applicationPool,
  [string]$physicalPath
)
$scriptName = 'IISWebSite.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------"
# When processing parameters, if parameters are not passed, set defaults if the site does not exist, otherwise list an example for information
executeExpression 'import-module WebAdministration'
if ($webSite) {
    Write-Host "[$scriptName] webSite            : $webSite"
} else {
	$webSite = 'Default Web Site'
    Write-Host "[$scriptName] webSite            : $webSite (default)"
}
if ($bindingProtocol) {
    Write-Host "[$scriptName] bindingProtocol    : $bindingProtocol"
    $options += "-bindingProtocol $bindingProtocol"
} else {
	if (Test-Path "iis:\Sites\$webSite") { 
	    Write-Host "[$scriptName] bindingProtocol    : (not passed) [example] http"
    } else {
    	$bindingProtocol = "http"
	    Write-Host "[$scriptName] bindingProtocol    : $bindingProtocol (not passed, set default as new website)"
	    $options += "-bindingProtocol $bindingProtocol"
    }
}
if ($bindingInformation) {
    Write-Host "[$scriptName] bindingInformation : $bindingInformation"
    $options += "-bindingInformation $bindingInformation"
} else {
	if (Test-Path "iis:\Sites\$webSite") { 
	    Write-Host "[$scriptName] bindingInformation : (not passed) [example] *:80:$webSite"
    } else {
    	$bindingInformation = ":80:$webSite"
	    Write-Host "[$scriptName] bindingInformation : $bindingInformation (not passed, set default as new website)"
	    $options += "-bindingInformation $bindingInformation"
    }
}
if ($applicationPool) {
    Write-Host "[$scriptName] applicationPool    : $applicationPool "
    $options += "-applicationPool $applicationPool"
} else {
	if (Test-Path "iis:\Sites\$webSite") { 
	    Write-Host "[$scriptName] applicationPool    : (not passed) [example] DefaultAppPool"
    } else {
    	$applicationPool = 'DefaultAppPool'
	    Write-Host "[$scriptName] applicationPool    : $applicationPool (not passed, set default as new website)"
	    $options += "-applicationPool $applicationPool"
    }
}
if ($physicalPath) {
    Write-Host "[$scriptName] physicalPath       : $physicalPath"
    $options += "-physicalPath $physicalPath"
} else {
	if (Test-Path "iis:\Sites\$webSite") { 
	    Write-Host "[$scriptName] physicalPath       : (not passed) [example] c:\inetpub\wwwroot"
    } else {
    	$physicalPath = 'c:\inetpub\wwwroot'
	    Write-Host "[$scriptName] physicalPath       : $physicalPath (not passed, set default as new website)"
	    $options += "-physicalPath $physicalPath"
    }
}

Write-Host "[$scriptName] Ensure IIS Service is running"
executeExpression "iisreset /start"

if ($applicationPool) {
	if (Test-Path "IIS:\AppPools\$applicationPool") {
	    Write-Host "`n[$scriptName] Application Pool $applicationPool exists"
	} else {
	    Write-Host "`n[$scriptName] Create Application Pool $applicationPool ..."
		$newPool = executeExpression "New-Item `'IIS:\AppPools\$applicationPool`'"
		Write-Host "`n[$scriptName] $($newPool.name) created"
	}
}

if ( $physicalPath ) {
	if (Test-Path "$physicalPath") {
	    Write-Host "`n[$scriptName] Physical path $physicalPath exists, no action required."
	} else {
	    Write-Host "`n[$scriptName] Create physical path $physicalPath ..."
		$newDir = executeExpression "New-Item -ItemType Directory -Force -Path `'$physicalPath`'"
		Write-Host "`n[$scriptName] $($newDir.FullName) created"
	}
}

Write-Host "`n[$scriptName] List Existing Sites"
executeExpression 'Get-ChildItem "IIS:\Sites" | Format-Table Name, ID, State, PhysicalPath, applicationPool'

if (Test-Path "iis:\Sites\$webSite") { 

	Write-Host "`n[$scriptName] List properties of existing site $webSite ..."
	executeExpression "Get-Item `"IIS:\Sites\$webSite`" | Format-Table "
	Write-Host "`n[$scriptName] Site ($webSite) exists, change properties (if passed)"
	if ($bindingInformation -or $bindingProtocol) {
		executeExpression "Set-ItemProperty IIS:\Sites\$webSite -name bindings -value @{protocol=`"$bindingProtocol`";bindingInformation=`"$bindingInformation`"} "
	}
	if ($applicationPool) {
		executeExpression "Set-ItemProperty IIS:\Sites\$webSite -name applicationPool -value `"$applicationPool`""
	}
	if ($physicalPath) {
		executeExpression "Set-ItemProperty IIS:\Sites\$webSite -name physicalPath -value `"$physicalPath`""
	}
	executeExpression "Get-Item `"IIS:\Sites\$webSite`" | Format-Table "

} else {
	
	Write-Host "`n[$scriptName] Create new site ($webSite)"
	$newSite = executeExpression "New-Item `"iis:\Sites\$webSite`" -bindings @{protocol=`"$bindingProtocol`";bindingInformation=`"$bindingInformation`"} -physicalPath $physicalPath -applicationPool $applicationPool"
	$newSite | Format-Table

}

executeExpression "Stop-Website -name `"$webSite`""
executeExpression "Start-Website -name `"$webSite`""

Write-Host "`n[$scriptName] List Sites After"
executeExpression 'Get-ChildItem "IIS:\Sites" | Format-Table Name, ID, State, PhysicalPath, applicationPool'

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0