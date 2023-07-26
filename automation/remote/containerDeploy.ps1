Param (
	[string]$TARGET,
	[string]$RELEASE,
	[string]$SOLUTION,
	[string]$BUILDNUMBER,
	[string]$REVISION,
	[string]$imageDir
)


# Consolidated Error processing function
#  required : error message
#  optional : exit code, if not supplied only error message is written
function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Red
	} else {
		Write-Warning "`n[$scriptName]$message"
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
	if ( $exitcode ) {
		if ( $env:CDAF_ERROR_DIAG ) {
			Write-Host "`n[$scriptName] Invoke custom diag `$env:CDAF_ERROR_DIAG = $env:CDAF_ERROR_DIAG`n"
			Invoke-Expression $env:CDAF_ERROR_DIAG
		}
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

$WORKSPACE = (Get-Location).Path
Write-Host "[$scriptName] pwd         : ${WORKSPACE}`n"

# 2.6.1 Prepare the image build directory and Dockerfile
if ( Test-Path $imageDir ) {
	Write-Host "`n[$scriptName] $imageDir exists, perform customer image build...`n"
} else {
	Write-Host "`n[$scriptName] $imageDir does not exist, creating $(mkdir $imageDir), with default Dockerfile...`n"

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
executeExpression "& '${WORKSPACE}/dockerRun.ps1' ${id}"
$env:CDAF_CD_ENVIRONMENT = $TARGET
executeExpression "& '${WORKSPACE}/dockerBuild.ps1' ${id} ${BUILDNUMBER}"
executeExpression "& '${WORKSPACE}/dockerClean.ps1' ${id} ${BUILDNUMBER}"

Write-Host "[$scriptName] Perform Remote Deployment activity using image ${id}:${BUILDNUMBER}"
foreach ( $envVar in Get-ChildItem env:) {
	if ($envVar.Name.Contains('CDAF_CD_')) {
		${buildCommand} += " --env $(${envVar}.Name.Replace('CDAF_CD_', ''))=$(${envVar}.Value)"
	}
}

${prefix} = (${SOLUTION}.ToUpper()).replace('-','_')
foreach ( $envVar in Get-ChildItem env:) {
	if ($envVar.Name.Contains("CDAF_${prefix}_CD_")) {
		${buildCommand} += " --env $(${envVar}.Name.Replace(`"CDAF_${prefix}_CD_`", ''))=$(${envVar}.Value)"
	}
}

if (( ! $env:USERPROFILE ) -or ( $env:CDAF_HOME_MOUNT -eq 'no' )) {
	Write-Host "[$scriptName] `$CDAF_HOME_MOUNT = ${env:CDAF_HOME_MOUNT} (environment variable)"
	Write-Host "[$scriptName] `$USERPROFILE     = ${env:USERPROFILE} (environment variable)"
	executeExpression "docker run ${buildCommand} --label cdaf.${id}.container.instance=${REVISION} --name ${id} ${id}:${BUILDNUMBER} deploy.bat ${TARGET}"
} else {
	executeExpression "docker run --volume '${env:USERPROFILE}:C:/solution/home' ${buildCommand} --label cdaf.${id}.container.instance=${REVISION} --name ${id} ${id}:${BUILDNUMBER} deploy.bat ${TARGET}"
}

Write-Host
executeExpression "& '${WORKSPACE}/dockerRun.ps1' ${id}"

Write-Host "`n[$scriptName] --- end ---"
