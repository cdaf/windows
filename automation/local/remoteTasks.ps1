
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
	$cdafVersion=$(& .\$WORK_DIR_DEFAULT\getProperty.ps1 .\$WORK_DIR_DEFAULT\$propertiesFile $propName)
	if(!$?){ taskWarning }
} catch { exceptionExit 'GET_CDAF_VERSION_104' $_ }

Write-Host "[$scriptName]   CDAF Version     : $cdafVersion"

# list system info
Write-Host "[$scriptName]   Hostname         : $(hostname)" 
Write-Host "[$scriptName]   Whoami           : $(whoami)" 
Write-Host "[$scriptName]   pwd              : $(pwd)"

$propertiesFilter = 'propertiesForRemoteTasks\' + "$ENVIRONMENT*"

$exitStatus = 0

# Perform Remote Tasks for each environment defintion file

if (-not(Test-Path $WORK_DIR_DEFAULT\$propertiesFilter)) {

	Write-Host "[$scriptName][WARN] local properties not found ($propertiesFilter) alter processSequence property to skip" -ForegroundColor Yellow

} else {

	Write-Host "`n[$scriptName] Preparing to process deploy targets :`n"
	foreach ($propFile in (Get-ChildItem -Path $WORK_DIR_DEFAULT\$propertiesFilter)) {
		$propFilename = getFilename($propFile.ToString())
		Write-Host "[$scriptName]   $propFilename"
	}

	foreach ($propFile in (Get-ChildItem -Path $WORK_DIR_DEFAULT\$propertiesFilter)) {
		$propFilename = getFilename($propFile.ToString())

		write-host "`n[$scriptName]   --- Process Target $propFilename ---`n" -ForegroundColor Green
		& .\$WORK_DIR_DEFAULT\remoteTasksTarget.ps1 $ENVIRONMENT $SOLUTION $BUILDNUMBER $propFilename $WORK_DIR_DEFAULT $OPT_ARG
		if($LASTEXITCODE -ne 0){ passExitCode "REMOTE_NON_ZERO_EXIT & .\$WORK_DIR_DEFAULT\localTasks.ps1 $ENVIRONMENT $BUILDNUMBER $SOLUTION $WORK_DIR_DEFAULT $OPT_ARG" $LASTEXITCODE }
		if(!$?){ taskWarning }

		write-host "`n[$scriptName]   --- Completed Target $propFilename ---`n" -ForegroundColor Green
	}
}
