$Error.clear()
$scriptName = $myInvocation.MyCommand.Name

function getProp ($propName) {

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

$ENVIRONMENT = $args[0]
Write-Host "[$scriptName]   ENVIRONMENT      : $ENVIRONMENT" 
$BUILD = $args[1]
Write-Host "[$scriptName]   BUILD            : $BUILD" 
$SOLUTION = $args[2]
Write-Host "[$scriptName]   SOLUTION         : $SOLUTION" 
$WORK_DIR_DEFAULT = $args[3]
Write-Host "[$scriptName]   WORK_DIR_DEFAULT : $WORK_DIR_DEFAULT" 
$OPT_ARG = $args[4]
Write-Host "[$scriptName]   OPT_ARG          : $OPT_ARG" 

$propertiesFile = ".\$WORK_DIR_DEFAULT\CDAF.properties"
$propName = getProp "productVersion"
Write-Host "[$scriptName]   CDAF Version     : $cdafVersion"

# list system info
Write-Host "[$scriptName]   hostname         : $(hostname)" 
Write-Host "[$scriptName]   whoami           : $(whoami)" 
Write-Host "[$scriptName]   pwd              : $(pwd)"

$propertiesFilter = $WORK_DIR_DEFAULT + '\propertiesForContainerTasks\' + "$ENVIRONMENT*"
if (-not(Test-Path $propertiesFilter)) {

	Write-Host "`n[$scriptName][WARN] Properties not found ($propertiesFilter) alter processSequence property to skip" -ForegroundColor Yellow

} else {
	# The containerDeploy is an extension to remote tasks, which means recursive call to this script should not happen (unlike containerBuild)
	# containerDeploy example & ${CDAF_WORKSPACE}/containerDeploy.ps1 "${ENVIRONMENT}" "${RELEASE}" "${SOLUTION}" "${BUILDNUMBER}" "${REVISION}"
	$propertiesFile = ".\$WORK_DIR_DEFAULT\manifest.txt"
	$containerDeploy = getProp 'containerDeploy'
	$REVISION = getProp 'REVISION'
	if ( $containerDeploy ) {
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
			${env:CONTAINER_IMAGE} = getProp 'containerImage'
			${CDAF_WORKSPACE} = "$(Get-Location)/${WORK_DIR_DEFAULT}"
			Set-Location "${CDAF_WORKSPACE}"
			Write-Host
			executeExpression "$containerDeploy"
			Set-Location "$landingDir"
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
}