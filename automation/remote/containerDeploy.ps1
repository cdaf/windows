Param (
	[string]$ENVIRONMENT,
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
		Write-Host "[$scriptName][EXCEPTION] List exception and error array (if populated) and exit with LASTEXITCIDE 1112" -ForegroundColor Red
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
if ($ENVIRONMENT) {
    Write-Host "[$scriptName] ENVIRONMENT : $ENVIRONMENT"
} else {
    Write-Host "[$scriptName] ENVIRONMENT not supplied, exit with `$LASTEXITCODE = 8021"; exit 8021
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
Write-Host

# Prepare the image build directory
if (!( Test-Path $imageDir )) {
	Write-Host "[$scriptName] $imageDir does not exist! Please ensure this is included in your storeFor or stoteForLocal declaration file"
	exit 8025
}
if ( Test-Path automation ) {
	executeExpression "cp -Recurse automation $imageDir"
}

executeExpression "cp -Recurse propertiesForContainerTasks $imageDir/properties"
executeExpression "cp ..\${SOLUTION}-${BUILDNUMBER}.zip $imageDir/deploy.zip"
executeExpression "cd $imageDir"

Write-Host "`n[$scriptName] Remove any remaining deploy containers from previous (failed) deployments"
$id = "${SOLUTION}_${REVISION}_containerdeploy".ToLower()
executeExpression "${CDAF_WORKSPACE}/dockerRun.ps1 ${id}"
$env:CDAF_CD_ENVIRONMENT = $ENVIRONMENT
executeExpression "${CDAF_WORKSPACE}/dockerBuild.ps1 ${id} ${BUILDNUMBER}"
executeExpression "${CDAF_WORKSPACE}/dockerClean.ps1 ${id} ${BUILDNUMBER}"

Write-Host "[$scriptName] Perform Remote Deployment activity using image ${id}:${BUILDNUMBER}"
foreach ( $envVar in Get-ChildItem env:) {
	if ($envVar.Name.Contains('CDAF_CD_')) {
		${buildCommand} += " --env $(${envVar}.Name.Replace('CDAF_CD_', ''))=$(${envVar}.Value)"
	}
}

${prefix} = ${SOLUTION}.ToUpper()
foreach ( $envVar in Get-ChildItem env:) {
	if ($envVar.Name.Contains("CDAF_${prefix}_CD_")) {
		${buildCommand} += " --env $(${envVar}.Name.Replace("CDAF_${prefix}_CD_", ''))=$(${envVar}.Value)"
	}
}

executeExpression "docker run --volume ${env:USERPROFILE}:C:/solution/home ${buildCommand} --label cdaf.${id}.container.instance=${REVISION} --name ${id} ${id}:${BUILDNUMBER} deploy.bat ${ENVIRONMENT}"

Write-Host
executeExpression "${CDAF_WORKSPACE}/dockerRun.ps1 ${id}"

Write-Host "`n[$scriptName] --- end ---"
