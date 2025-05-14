Param (
  [string]$webSite,
  [string]$bindingProtocol,
  [string]$bindingInformation,
  [string]$applicationPool,
  [string]$physicalPath
)

$scriptName = 'IISWebSite.ps1'
$error.clear()
cmd /c "exit 0"

# Consolidated Error processing function
function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Red
	} else {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Yellow
	}
	if ( $error ) {
		$i = 0
		foreach ( $item in $Error )
		{
			Write-Host "`$Error[$i] $item"
			$i++
		}
		$Error.clear()
	}
	if ( $env:CDAF_ERROR_DIAG ) {
		Write-Host "`n[$scriptName] Invoke custom diag `$env:CDAF_ERROR_DIAG = $env:CDAF_ERROR_DIAG`n"
		Invoke-Expression $env:CDAF_ERROR_DIAG
	}
	if ( $exitcode ) {
		Write-Host "`n[$scriptName] Exit with LASTEXITCODE = $exitcode`n" -ForegroundColor Red
		exit $exitcode
	}
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { ERRMSG "[TRAP] `$? = $?" 1211 }
	} catch {
		$message = $_.Exception.Message
		$_.Exception | format-list -force
		$_.Exception.StackTrace
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
			ERRMSG "[EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			ERRMSG "[EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
		} else {
			if ( $error ) {
				ERRMSG "[WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				ERRMSG "[WARN] `$LASTEXITCODE not set, but standard error populated"
	    	}
		}
	}
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
    	$bindingProtocol = "http"
	    Write-Host "[$scriptName] bindingProtocol    : (not passed, set default, this will affect the existing site)"
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
	if ( $bindingInformation ) {
		executeExpression "Set-ItemProperty IIS:\Sites\$webSite -name bindings -value @{protocol=`"$bindingProtocol`";bindingInformation=`"$bindingInformation`"} "
	}
	if ( $applicationPool ) {
		executeExpression "Set-ItemProperty IIS:\Sites\$webSite -name applicationPool -value `"$applicationPool`""
	}
	if ( $physicalPath ) {
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