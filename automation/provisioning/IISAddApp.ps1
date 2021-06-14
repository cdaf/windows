Param (
  [string]$app,
  [string]$physicalPath,
  [string]$site,
  [string]$appPool,
  [string]$clrVersion
)

$scriptName = 'IISAddApp.ps1'
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

if (Test-Path "$physicalPath") {
    Write-Host "`n[$scriptName] Physical path $physicalPath exists, no action required."
} else {
	$newDir = executeExpression "New-Item -ItemType Directory -Force -Path `'$physicalPath`'"
	Write-Host "`n[$scriptName] Created $($newDir.FullName)"
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
