Param (
	$appList
)

$Error.Clear()
cmd /c "exit 0"
$scriptName = 'deploy.ps1'

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
			ERRMSG "[EXEC][EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[EXEC][EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			ERRMSG "[EXEC][EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
		} else {
			if ( $error ) {
				ERRMSG "[EXEC][WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[EXEC][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				ERRMSG "[EXEC][WARN] `$LASTEXITCODE not set, but standard error populated"
	    	}
		}
	}
}

Write-Host "`n[$scriptName] ---------- start ----------"
Write-Host "[$scriptName]   SOLUTION       : $SOLUTION"
Write-Host "[$scriptName]   BUILD          : $BUILD"
Write-Host "[$scriptName]   ENVIRONMENT    : $ENVIRONMENT"
Write-Host "[$scriptName]   TARGET         : $TARGET"
Write-Host "[$scriptName]   WORKSPACE      : $WORKSPACE"
Write-Host "[$scriptName]   resource_group : $resource_group"

Write-Host "[$scriptName] Is msdeploy installed?"
$absPath = & where.exe msdeploy.exe 2>null
if ( $LASTEXITCODE -ne 0 ) {
	$absPath = "C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe"
	try {
		& $absPath
	} catch {
		$absPath = "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe"
		try {
			& $absPath
		} catch {
			ERRMSG "[MSDEPLOY_NOT_FOUND] msdeploy not on path or default locations!" 42863
		}
	
	}
}

foreach ($app in  $appList ) {
	$webAppName = $app.name
	if ( $webAppName -match 'free-' ) {
		$publishProfile = az webapp deployment list-publishing-profiles --resource-group $resource_group --name $webAppName --query "[?publishMethod=='MSDeploy']" | ConvertFrom-Json
		$userName = $publishProfile.userName
		$userPWD = $publishProfile.userPWD
		Write-Host "Deploy ${webAppName} as ${userName}..."
		executeExpression "& '$absPath' -verb:sync -source:dirPath='$WORKSPACE',includeAcls=false -dest:dirpath=D:\home\site\freecover,ComputerName='https://$webAppName.scm.azurewebsites.net/msdeploy.axd?site=$($webAppName)',UserName=`${userName},Password=`${userPWD},AuthType='Basic' -verbose -debug"

	} else {
		Write-Host "Skip = $webAppName"
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------"
