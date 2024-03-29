# executeExpression and ERRMSG inherited from delivery.ps1

$scriptName = $myInvocation.MyCommand.Name 

Write-Host "`n[$scriptName] +---------------------------------+"
Write-Host "[$scriptName] | Process Remotely Executed Tasks |"
Write-Host "[$scriptName] +---------------------------------+"

$ENVIRONMENT = $args[0]
Write-Host "[$scriptName]   ENVIRONMENT      : $ENVIRONMENT" 
$BUILDNUMBER = $args[1]
Write-Host "[$scriptName]   BUILDNUMBER      : $BUILDNUMBER" 
$SOLUTION = $args[2]
Write-Host "[$scriptName]   SOLUTION         : $SOLUTION" 
$WORK_DIR_DEFAULT = $args[3]
Write-Host "[$scriptName]   WORK_DIR_DEFAULT : $WORK_DIR_DEFAULT" 
$OPT_ARG = $args[4]
Write-Host "[$scriptName]   OPT_ARG          : $OPT_ARG" 

$propertiesFile = "CDAF.properties"
$propName = "productVersion"
try {
	$cdafVersion=$(& $WORK_DIR_DEFAULT\getProperty.ps1 $WORK_DIR_DEFAULT\$propertiesFile $propName)
	if(!$?){ taskWarning }
} catch { exceptionExit 'GET_CDAF_VERSION_104' $_ }

Write-Host "[$scriptName]   CDAF Version     : $cdafVersion"

$WORKSPACE = (Get-Location).Path
Write-Host "[$scriptName]   WORKSPACE        : $WORKSPACE"
# list system info
Write-Host "[$scriptName]   Hostname         : $(hostname)" 
Write-Host "[$scriptName]   Whoami           : $(whoami)" 
Write-Host "[$scriptName]   pwd              : $(pwd)"

$propertiesFilter = 'propertiesForRemoteTasks\' + "$ENVIRONMENT*"

$exitStatus = 0

# Perform Remote Tasks for each environment defintion file

if (-not(Test-Path $WORK_DIR_DEFAULT\$propertiesFilter)) {

	Write-Host "`n[$scriptName][WARN] Properties not found ($propertiesFilter) alter processSequence property to skip" -ForegroundColor Yellow

} else {

	Write-Host "`n[$scriptName] Preparing to process deploy targets :`n"
	foreach ($propFile in (Get-ChildItem -Path $WORK_DIR_DEFAULT\$propertiesFilter)) {
		$propFilename = getFilename($propFile.ToString())
		Write-Host "[$scriptName]   $propFilename"
	}

	foreach ($propFile in (Get-ChildItem -Path $WORK_DIR_DEFAULT\$propertiesFilter)) {
		$propFilename = getFilename($propFile.ToString())

		write-host "`n[$scriptName]   --- Process Target $propFilename ---`n" -ForegroundColor Green
		executeExpression "& '$WORK_DIR_DEFAULT\remoteTasksTarget.ps1' '$ENVIRONMENT' '$SOLUTION' '$BUILDNUMBER' '$propFilename' '$WORK_DIR_DEFAULT' '$OPT_ARG'"
	    if ( "$(pwd)" -ne $WORKSPACE ){
			Write-Host "`n[$scriptName] Return to WORKSPACE" 
		    executeExpression "  cd $WORKSPACE"
	    }

		write-host "`n[$scriptName]   --- Completed Target $propFilename ---`n" -ForegroundColor Green
	}

	if ( "$(pwd)" -ne $WORKSPACE ){
		Write-Host "`n[$scriptName] Return to WORKSPACE" 
	    executeExpression "  cd $WORKSPACE"
	}
	
	Write-Host "[$scriptName] +----------------------------------+"
	Write-Host "[$scriptName] | Competed Remotely Executed Tasks |"
	Write-Host "[$scriptName] +----------------------------------+"
}

exit 0