Param (
	[string]$imageName,
	[string]$buildNumber,
	[string]$rebuildImage
)

$scriptName = 'containerBuild.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

# Use the CDAF provisioning helpers
Write-Host "`n[$scriptName] ---------- start ----------`n"
if ( $imageName ) {
	Write-Host "[$scriptName]   imageName    : ${imageName}"
} else {
	Write-Host "[$scriptName]   imageName not supplied, exit with code 99"; exit 99
}

if ( $buildNumber ) { 
	Write-Host "[$scriptName]   buildNumber  : $buildNumber"
} else {
	Write-Host "[$scriptName]   buildNumber  : (not supplied)"
}

if ( $rebuildImage ) {
	Write-Host "[$scriptName]   rebuildImage : $rebuildImage (choices are yes, no or imageonly)"
} else {
	$rebuildImage = 'no'
	Write-Host "[$scriptName]   rebuildImage : $rebuildImage (not supplied, so set to default)"
}

Write-Host "[$scriptName]   DOCKER_HOST  : $env:DOCKER_HOST"
Write-Host "[$scriptName]   pwd          : $(pwd)"
Write-Host "[$scriptName]   hostname     : $(hostname)"
Write-Host "[$scriptName]   whoami       : $(whoami)"

# Test Docker is running
Write-Host "[$scriptName] List all current images"
executeExpression "docker images"

$imageTag = 0
foreach ( $imageDetails in docker images --filter label=cdaf.${imageName}.image.version --format "{{.Tag}}" ) {
	if ($imageTag -lt [INT]$imageDetails ) { $imageTag = [INT]$imageDetails }
}
if ( $imageTag ) {
	Write-Host "[$scriptName] Last image tag is $imageTag, new image will be $($imageTag + 1)"
} else {
	$imageTag = 0
	Write-Host "[$scriptName] No existing images, new image will be $($imageTag + 1)"
}
executeExpression "cat Dockerfile"
	
if ( $rebuildImage -eq 'yes') {
	# Force rebuild, i.e. no-cache
	executeExpression "automation/remote/dockerBuild.ps1 ${imageName} $($imageTag + 1) -rebuild yes"
} else {
	executeExpression "automation/remote/dockerBuild.ps1 ${imageName} $($imageTag + 1)"
}

# Remove any older images	
executeExpression "automation/remote/dockerClean.ps1 ${imageName} $($imageTag + 1)"

if ( $rebuildImage -ne 'imageonly') {
	# Retrieve the latest image number
	$imageTag = 0
	foreach ( $imageDetails in docker images --filter label=cdaf.${imageName}.image.version --format "{{.Tag}}" ) {
		if ($imageTag -lt [INT]$imageDetails ) { $imageTag = [INT]$imageDetails }
	}

	$workspace = (Get-Location).Path
	Write-Host "[$scriptName] `$imageTag  : $imageTag"
	Write-Host "[$scriptName] `$workspace : $workspace"
	
	if ( $buildNumber ) {
		executeExpression "docker run --tty --volume ${workspace}\:C:/workspace ${imageName}:${imageTag} automation\provisioning\runner.bat automation\remote\entrypoint.ps1 $buildNumber"
	} else {
		executeExpression "docker run --tty --volume ${workspace}\:C:/workspace ${imageName}:${imageTag} automation\provisioning\runner.bat automation\remote\entrypoint.ps1"
	}
	
	Write-Host "`n[$scriptName] List and remove all stopped containers"
	executeExpression "docker ps --filter `"status=exited`" -a"
	executeExpression "docker rm (docker ps --filter `"status=exited`" -aq)"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0
