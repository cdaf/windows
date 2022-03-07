Param (
	[string]$ENVIRONMENT,
	[string]$BUILD,
	[string]$SOLUTION,
	[string]$WORK_DIR_DEFAULT,
	[string]$OPT_ARG
)

$Error.clear()
$scriptName = $myInvocation.MyCommand.Name

function getProp ($propertiesFile, $propName) {

	try {
		$propValue=$(& $WORK_DIR_DEFAULT\getProperty.ps1 $propertiesFile $propName)
		if(!$?){ taskWarning }
	} catch { exceptionExit CONTAINER_TASKS $_ }
	
    return $propValue
}

Write-Host
Write-Host "[$scriptName] +-------------------------+"
Write-Host "[$scriptName] | Process Container Tasks |"
Write-Host "[$scriptName] +-------------------------+"
Write-Host "[$scriptName]   ENVIRONMENT      : $ENVIRONMENT" 
Write-Host "[$scriptName]   BUILD            : $BUILD" 
Write-Host "[$scriptName]   SOLUTION         : $SOLUTION" 
Write-Host "[$scriptName]   WORK_DIR_DEFAULT : $WORK_DIR_DEFAULT" 
Write-Host "[$scriptName]   OPT_ARG          : $OPT_ARG" 
 
$propName = getProp ".\$WORK_DIR_DEFAULT\CDAF.properties" "productVersion"
Write-Host "[$scriptName]   CDAF Version     : $cdafVersion"

# list system info
Write-Host "[$scriptName]   hostname         : $(hostname)" 
Write-Host "[$scriptName]   whoami           : $(whoami)"
$landingDir = pwd
Write-Host "[$scriptName]   pwd              : $landingDir"

$propertiesFilter = $WORK_DIR_DEFAULT + '\propertiesForContainerTasks\' + "$ENVIRONMENT*"
if (-not(Test-Path $propertiesFilter)) {

	Write-Host "`n[$scriptName][INFO] Properties directory ($propertiesFilter) not found, alter processSequence property to skip." -ForegroundColor Yellow

} else {
	# 2.4.0 The containerDeploy is an extension to remote tasks, which means recursive call to this script should not happen (unlike containerBuild)
	# containerDeploy example & ${CDAF_WORKSPACE}/containerDeploy.ps1 "${ENVIRONMENT}" "${RELEASE}" "${SOLUTION}" "${BUILDNUMBER}" "${REVISION}"
	$propertiesFile = ".\$WORK_DIR_DEFAULT\manifest.txt"
	$containerDeploy = getProp $propertiesFile 'containerDeploy'
	$REVISION = getProp $propertiesFile 'REVISION'
	if ( ! $containerDeploy ) {
		Write-Host "`n[$scriptName][INFO] containerDeploy not set in CDAF.solution, using default." -ForegroundColor Yellow
		containerDeploy = '& ${CDAF_WORKSPACE}/containerDeploy.ps1 "${ENVIRONMENT}" "${RELEASE}" "${SOLUTION}" "${BUILDNUMBER}" "${REVISION}"'
	}
	try { $instances = docker ps 2>$null } catch {
		Write-Host "[$scriptName]   containerDeploy  : containerDeploy defined in $WORK_DIR_DEFAULT\manifest.txt, but Docker not installed, will attempt to execute natively`n"
		Clear-Variable -Name 'containerDeploy'
		$Error.clear()
	}
	if ( $LASTEXITCODE -ne 0 ) {
		Write-Host "[$scriptName]   containerDeploy  : containerDeploy defined in $WORK_DIR_DEFAULT\manifest.txt, but Docker not running, will attempt to execute natively`n"
		Clear-Variable -Name 'containerDeploy'
		$Error.clear()
		cmd /c "exit 0"
	} else {
		${env:CONTAINER_IMAGE} = getProp $propertiesFile 'containerImage'
		${CDAF_WORKSPACE} = "$(Get-Location)/${WORK_DIR_DEFAULT}"
		executeExpression "Set-Location '${CDAF_WORKSPACE}'"
		Write-Host
		executeExpression "$containerDeploy"
		executeExpression "Set-Location '$landingDir'"
	}
	if (!( $containerDeploy )) {
		if ( Test-Path $WORK_DIR_DEFAULT\propertiesForLocalTasks\$ENVIRONMENT* ) {
			Write-Host "[$scriptName]   Cannot use container properties for local execution as existing local definition exits"
		} else {
			Write-Host "[$scriptName]   Use container properties for local execution"
			if (!( Test-Path $WORK_DIR_DEFAULT\propertiesForLocalTasks\ )) {
				Write-Host "  Created $(mkdir $WORK_DIR_DEFAULT\propertiesForLocalTasks\)"
			}
			foreach ( $propFile in Get-Childitem $WORK_DIR_DEFAULT\propertiesForContainerTasks\$ENVIRONMENT* ) {
				executeExpression "cp $propFile $WORK_DIR_DEFAULT\propertiesForLocalTasks\"
			}
			executeExpression "& .\$WORK_DIR_DEFAULT\localTasks.ps1 '$ENVIRONMENT' '$BUILDNUMBER' '$SOLUTION' '$WORK_DIR_DEFAULT' '$OPT_ARG'"
		}
	}
}