
$scriptName = $myInvocation.MyCommand.Name

Write-Host
Write-Host "[$scriptName] +-------------------------+"
Write-Host "[$scriptName] | Process Container Tasks |"
Write-Host "[$scriptName] +-------------------------+"

$ENVIRONMENT = $args[0]
Write-Host "[$scriptName]   ENVIRONMENT            : $ENVIRONMENT" 
$BUILD = $args[1]
Write-Host "[$scriptName]   BUILD                  : $BUILD" 
$SOLUTION = $args[2]
Write-Host "[$scriptName]   SOLUTION               : $SOLUTION" 
$WORK_DIR_DEFAULT = $args[3]
Write-Host "[$scriptName]   WORK_DIR_DEFAULT       : $WORK_DIR_DEFAULT" 
$OPT_ARG = $args[4]
Write-Host "[$scriptName]   OPT_ARG                : $OPT_ARG" 

$propertiesFile = "CDAF.properties"
$propName = "productVersion"
try {
	$cdafVersion=$(& .\$WORK_DIR_DEFAULT\getProperty.ps1 .\$WORK_DIR_DEFAULT\$propertiesFile $propName)
	if(!$?){ taskWarning }
} catch { exceptionExit 'GET_CDAF_VERSION_105' $_ }

Write-Host "[$scriptName]   CDAF Version           : $cdafVersion"

# list system info
Write-Host "[$scriptName]   Hostname               : $(hostname)" 
Write-Host "[$scriptName]   Whoami                 : $(whoami)" 
Write-Host "[$scriptName]   pwd                    : $(pwd)"

$propertiesFilter = 'propertiesForContainerTasks\' + "$ENVIRONMENT*"

if (-not(Test-Path $propertiesFilter)) {

	Write-Host "[$scriptName][WARN] local properties not found ($propertiesFilter) alter processSequence property to skip" -ForegroundColor Yellow

} else {
	# The containerDeploy is an extension to remote tasks, which means recursive call to this script should not happen (unlike containerBuild)
	# containerDeploy example & ${CDAF_WORKSPACE}/containerDeploy.ps1 "${ENVIRONMENT}" "${RELEASE}" "${SOLUTION}" "${BUILDNUMBER}" "${REVISION}"
	if ( Test-Path $WORK_DIR_DEFAULT\propertiesForContainerTasks\$ENVIRONMENT ) {
		$containerDeploy = getProp 'containerDeploy'
		$REVISION = getProp 'REVISION'
		if ( $containerDeploy ) {
			try { $instances = docker ps 2>$null } catch {
				Write-Host "[$scriptName]   containerDeploy  : containerDeploy defined in $WORK_DIR_DEFAULT\manifest.txt, but Docker not installed, will attempt to execute natively"
				Clear-Variable -Name 'containerDeploy'
				$Error.clear()
			}
			if ( $LASTEXITCODE -ne 0 ) {
				Write-Host "[$scriptName]   containerDeploy  : containerDeploy defined in $WORK_DIR_DEFAULT\manifest.txt, but Docker not running, will attempt to execute natively"
				Clear-Variable -Name 'containerDeploy'
				$Error.clear()
			} else {
				${env:CONTAINER_IMAGE} = getProp 'containerImage'
				${CDAF_WORKSPACE} = "$(Get-Location)/${WORK_DIR_DEFAULT}"
				Set-Location "${CDAF_WORKSPACE}"
				Write-Host
				executeExpression "$containerDeploy"
				Set-Location "$landingDir"
			}
			if (( Test-Path $WORK_DIR_DEFAULT\propertiesForLocalTasks\$ENVIRONMENT ) -or ( Test-Path $WORK_DIR_DEFAULT\propertiesForRemoteTasks\$ENVIRONMENT )){
				Clear-Variable -Name 'containerDeploy'
			}
		}
	}
}