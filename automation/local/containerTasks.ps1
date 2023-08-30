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

# Capture landing directory, then change to Default Working Directory and resolve to absolute path
Set-Location $WORK_DIR_DEFAULT
$WORK_DIR_DEFAULT = (Get-Location).Path

Write-Host "[$scriptName]   OPT_ARG          : $OPT_ARG" 
 
$propName = getProp "$WORK_DIR_DEFAULT\CDAF.properties" "productVersion"
Write-Host "[$scriptName]   CDAF Version     : $cdafVersion"

# list system info
Write-Host "[$scriptName]   hostname         : $(hostname)" 
Write-Host "[$scriptName]   whoami           : $(whoami)"
Write-Host "[$scriptName]   pwd              : $WORK_DIR_DEFAULT"

$propertiesFilter = 'propertiesForContainerTasks\' + "$ENVIRONMENT*"
if (-not(Test-Path $propertiesFilter)) {

	Write-Host "`n[$scriptName][WARN] Properties not found ($propertiesFilter) alter processSequence property to skip." -ForegroundColor Yellow

} else {
	# 2.4.0 Introduce containerDeploy as a prescriptive "remote" process, changed in 2.5.0 to allow re-use of compose assets
	$containerDeploy = getProp 'manifest.txt' 'containerDeploy'
	$REVISION = getProp 'manifest.txt' 'REVISION'

	# 2.5.0 Provide default containerDeploy execution, replacing "remote" process with "local" process, but retaining containerRemote.ps1 to support 2.4.0 functionality
	if ( ! $containerDeploy ) {
		Write-Host "`n[$scriptName][INFO] containerDeploy not set in CDAF.solution, using default." -ForegroundColor Yellow
		$containerDeploy = '& "$CDAF_CORE\containerDeploy.ps1" "${TARGET}" "${RELEASE}" "${SOLUTION}" "${BUILDNUMBER}" "${REVISION}"'
	}

	# Verify docker available, if not, fall-back to native execution
	try { $instances = docker ps 2>$null } catch {
		ERRMSG "[DEPLOY_BASE_IMAGE_NOT_DEFINED] containerDeploy defined in $WORK_DIR_DEFAULT\manifest.txt, but Docker not installed" 3912
	}
	if ( $LASTEXITCODE -ne 0 ) {
		ERRMSG "[DEPLOY_BASE_IMAGE_NOT_DEFINED] containerDeploy defined in $WORK_DIR_DEFAULT\manifest.txt, but Docker not running" 3913
	}

	$deployImage = getProp 'manifest.txt' 'deployImage'
	if ( $deployImage ) {
		${env:CONTAINER_IMAGE} = $deployImage
		Write-Host "[$scriptName]   `${env:CONTAINER_IMAGE} = ${env:CONTAINER_IMAGE} (deployImage)"
	} else {
		$runtimeImage = getProp 'manifest.txt' 'runtimeImage'
		if ( $runtimeImage ) {
			${env:CONTAINER_IMAGE} = $runtimeImage
			Write-Host "[$scriptName]   `${env:CONTAINER_IMAGE} = ${env:CONTAINER_IMAGE} (runtimeImage)"
		} else {
			$containerImage = getProp 'manifest.txt' 'containerImage'
			if ( $containerImage ) {
				${env:CONTAINER_IMAGE} = $containerImage
				Write-Host "[$scriptName]   `${env:CONTAINER_IMAGE} = ${env:CONTAINER_IMAGE} (containerImage)"
			} else {
				ERRMSG "[DEPLOY_BASE_IMAGE_NOT_DEFINED] Base image not defined in either deployImage, runtimeImage nor containerImage in CDAF.solution" 3911
			}
		}
	}

	# 2.5.3 Option to disable volume mount for containerDeploy
	$homeMount = getProp 'manifest.txt' CDAF_HOME_MOUNT
	if ( $homeMount ) {
		$env:CDAF_HOME_MOUNT = $homeMount
		Write-Host "[$scriptName]   `${env:CDAF_HOME_MOUNT} = ${env:CDAF_HOME_MOUNT} (solution override)"
	} else {
		Write-Host "[$scriptName]   `${env:CDAF_HOME_MOUNT} = ${env:CDAF_HOME_MOUNT}"
	}

	# 2.5.0 Process all containerDeploy environments based on prefix pattern (align with localTasks and remoteTasks)
	Write-Host "`n[$scriptName] Preparing to process deploy targets :`n"
	foreach ($propFile in (Get-ChildItem -Path $WORK_DIR_DEFAULT\$propertiesFilter)) {
		$propFilename = getFilename($propFile.ToString())
		Write-Host "[$scriptName]   $propFilename"
	}

	foreach ($propFile in (Get-ChildItem -Path $WORK_DIR_DEFAULT\$propertiesFilter)) {
		$TARGET = getFilename($propFile.ToString())
		Write-Host "`n[$scriptName] Processing `$TARGET = $TARGET...`n"
		executeExpression "$containerDeploy"
		executeExpression "Set-Location '$WORK_DIR_DEFAULT'" # Return to Landing Directory in case a custom containerTask has been used, e.g. containerRemote
	}
}