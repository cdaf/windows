Param (
	[string]$TARGET,
	[string]$RELEASE,
	[string]$SOLUTION,
	[string]$BUILDNUMBER,
	[string]$REVISION,
	[string]$imageDir
)

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression "$expression 2> `$null"
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch {
		Write-Host "[$scriptName][EXCEPTION] List exception and error array (if populated) and exit with LASTEXITCODE 1112" -ForegroundColor Red
		Write-Host $_.Exception|format-list -force
		if ( $error ) { Write-Host "[$scriptName][ERROR] `$Error = $Error" ; $Error.clear() }
		exit 1112
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red
			if ( $error ) { Write-Host "[$scriptName][ERROR] `$Error = $Error" ; $Error.clear() }
			exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				Write-Host "[$scriptName][WARN] `$Error = $Error" ; $Error.clear()
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				Write-Host "[$scriptName][ERROR] `$Error = $error"; $Error.clear()
				Write-Host "[$scriptName][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting with LASTEXITCODE 1113 ..."; exit 1113
	    	} else {
		    	Write-Host "[$scriptName][WARN] `$Error = $error" ; $Error.clear()
	    	}
		}
	}
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeSuppress ($expression) {
	Write-Host "$expression"
	try {
		Invoke-Expression "$expression 2> `$null"
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception|format-list -force; exit 2 }
	$error.clear()
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] Suppress `$LASTEXITCODE ($LASTEXITCODE)"; cmd /c "exit 0" } # reset LASTEXITCODE
}

$scriptName = 'containerDeploy.ps1'
$Error.clear()
cmd /c "exit 0"

Write-Host "`n[$scriptName] Build docker image, resulting image BUILDNUMBER will be ${SOLUTION}:${BUILDNUMBER}"
Write-Host "`n[$scriptName] ---------- start ----------"
if ($TARGET) {
    Write-Host "[$scriptName] TARGET      : $TARGET"
} else {
    Write-Host "[$scriptName] TARGET not supplied, exit with `$LASTEXITCODE = 8021"; exit 8021
}

if ($RELEASE) {
    Write-Host "[$scriptName] RELEASE     : $RELEASE"
} else {
    Write-Host "[$scriptName] RELEASE not supplied, exit with `$LASTEXITCODE = 8022"; exit 8022
}

if ($SOLUTION) {
	$SOLUTION = $SOLUTION.ToLower()
    Write-Host "[$scriptName] SOLUTION    : $SOLUTION"
} else {
    Write-Host "[$scriptName] SOLUTION not supplied, exit with `$LASTEXITCODE = 8023"; exit 8023
}

if ($BUILDNUMBER) {
    Write-Host "[$scriptName] BUILDNUMBER : $BUILDNUMBER"
} else {
    Write-Host "[$scriptName] BUILDNUMBER not supplied, exit with `$LASTEXITCODE = 8024"; exit 8024
}

if ($REVISION) {
    Write-Host "[$scriptName] REVISION    : $REVISION"
} else {
	$REVISION = 'container-deploy'
    Write-Host "[$scriptName] REVISION    : $REVISION (not supplied, default set)"
}

if ($imageDir) {
    Write-Host "[$scriptName] imageDir    : $imageDir"
} else {
	$imageDir = 'containerDeploy'
    Write-Host "[$scriptName] imageDir    : $imageDir (not supplied, default set)"
}

$env:WORKSPACE = (Get-Location).Path
Write-Host "[$scriptName] pwd         : ${env:WORKSPACE}`n"

# Prepare the image build directory
if (!( Test-Path $imageDir )) {
	Write-Host "`n[$scriptName] $imageDir does not exist, creating default using CDAF image`n"
	executeExpression "mkdir $imageDir"
	Write-Host

	Set-Content "${imageDir}/Dockerfile" '# DOCKER-VERSION 1.2.0'
	Add-Content "${imageDir}/Dockerfile" 'ARG CONTAINER_IMAGE'
	Add-Content "${imageDir}/Dockerfile" 'FROM ${CONTAINER_IMAGE}'
	Add-Content "${imageDir}/Dockerfile" ''
	Add-Content "${imageDir}/Dockerfile" '# Copy solution, provision and then build'
	Add-Content "${imageDir}/Dockerfile" 'WORKDIR /solution'
	Add-Content "${imageDir}/Dockerfile" ''
	Add-Content "${imageDir}/Dockerfile" 'COPY properties/* /solution/deploy/'
	Add-Content "${imageDir}/Dockerfile" 'COPY deploy.zip .'
	Add-Content "${imageDir}/Dockerfile" 'RUN powershell -Command Expand-Archive deploy.zip'
	Add-Content "${imageDir}/Dockerfile" ''
	Add-Content "${imageDir}/Dockerfile" '# Unlike containerBuild the workspace is not volume mounted, this replicates what the remote deploy process does leaving the image ready to run'
	Add-Content "${imageDir}/Dockerfile" 'WORKDIR /solution/deploy'
	Add-Content "${imageDir}/Dockerfile" 'CMD ["./deploy.ps1", "${ENVIRONMENT}"]'

	Get-Content "${imageDir}/Dockerfile"
	Write-Host
}

if ( Test-Path automation ) {
	executeExpression "cp -Recurse automation $imageDir"
}

executeExpression "cp -Recurse propertiesForContainerTasks $imageDir/properties"

if ( Test-Path "..\${SOLUTION}-${BUILDNUMBER}.zip" ) {
	executeExpression "cp ..\${SOLUTION}-${BUILDNUMBER}.zip $imageDir/deploy.zip"
} else {
	Write-Host "`n[$scriptName][INFO] ..\${SOLUTION}-${BUILDNUMBER}.zip not found.`n"
}

executeExpression "cd $imageDir"

Write-Host "`n[$scriptName] Remove any remaining deploy containers from previous (failed) deployments"
$id = "${SOLUTION}_${REVISION}_containerdeploy".ToLower()
executeExpression "${env:WORKSPACE}/dockerRun.ps1 ${id}"
$env:CDAF_CD_ENVIRONMENT = $TARGET
executeExpression "${env:WORKSPACE}/dockerBuild.ps1 ${id} ${BUILDNUMBER}"
executeExpression "${env:WORKSPACE}/dockerClean.ps1 ${id} ${BUILDNUMBER}"

Write-Host "[$scriptName] Perform Remote Deployment activity using image ${id}:${BUILDNUMBER}"
foreach ( $envVar in Get-ChildItem env:) {
	if ($envVar.Name.Contains('CDAF_CD_')) {
		${buildCommand} += " --env $(${envVar}.Name.Replace('CDAF_CD_', ''))=$(${envVar}.Value)"
	}
}

${prefix} = (${SOLUTION}.ToUpper()).replace('-','_')
foreach ( $envVar in Get-ChildItem env:) {
	if ($envVar.Name.Contains("CDAF_${prefix}_CD_")) {
		${buildCommand} += " --env $(${envVar}.Name.Replace("CDAF_${prefix}_CD_", ''))=$(${envVar}.Value)"
	}
}

if (( ! ${env:USERPROFILE} ) -or ( ${env:CDAF_HOME_MOUNT} -eq 'no' )) {
	Write-Host "[$scriptName] `${env:CDAF_HOME_MOUNT} = ${env:CDAF_HOME_MOUNT}"
	Write-Host "[$scriptName] `${env:USERPROFILE}     = ${env:USERPROFILE}"
	executeExpression "docker run ${buildCommand} --label cdaf.${id}.container.instance=${REVISION} --name ${id} ${id}:${BUILDNUMBER} deploy.bat ${TARGET}"
} else {
	executeExpression "docker run --volume ${env:USERPROFILE}:C:/solution/home ${buildCommand} --label cdaf.${id}.container.instance=${REVISION} --name ${id} ${id}:${BUILDNUMBER} deploy.bat ${TARGET}"
}

Write-Host
executeExpression "${env:WORKSPACE}/dockerRun.ps1 ${id}"

Write-Host "`n[$scriptName] --- end ---"
