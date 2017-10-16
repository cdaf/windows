Param (
	[string]$imageName,
	[string]$buildNumber,
	[string]$command,
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

if ( $command ) {
	Write-Host "[$scriptName]   command      : $command"
} else {
	Write-Host "[$scriptName]   command      : (not supplied)"
}

if ( $rebuildImage ) {
	Write-Host "[$scriptName]   rebuildImage : $rebuildImage"
} else {
	$rebuildImage = 'no'
	Write-Host "[$scriptName]   rebuildImage : $rebuildImage (not supplied, so set to default)"
}

Write-Host "[$scriptName]   DOCKER_HOST  : $env:DOCKER_HOST"

# Test Docker is running
Write-Host "[$scriptName] List all current images"
executeExpression "docker images"

$imageExists = (docker images --filter=label=cdaf.${imageName}.image.version -q)
if (!( $imageExists )) {
	Write-Host "[$scriptName] No build image exists, initialise (ignore `$rebuildImage)"
	$rebuildImage = 'yes'
}

if ( $rebuildImage -eq 'yes') {
	foreach ( $imageDetails in docker images --filter label=cdaf.${imageName}.image.version --format "{{.ID}}:{{.Tag}}:{{.Repository}}" ) {
		$arr = $imageDetails.split(':')
		$imageTag = [INT]$arr[1]
	}
	if ( $imageTag ) {
		Write-Host "[$scriptName] Last image tag is $imageTag, new image will be $($imageTag + 1)"
	} else {
		$imageTag = 0
		Write-Host "[$scriptName] No existing images, new image will be $($imageTag + 1)"
	}
	executeExpression "cat Dockerfile"
	
	# Do not execute using function as interactive logging stops working
	executeExpression "automation/remote/dockerBuild.ps1 ${imageName} $($imageTag + 1) -rebuild yes"

	# Remove any older images	
	executeExpression "automation/remote/dockerClean.ps1 ${imageName} $($imageTag + 1)"
}

# Retrieve the latest image number
foreach ( $imageDetails in docker images --filter label=cdaf.${imageName}.image.version --format "{{.ID}}:{{.Tag}}:{{.Repository}}" ) {
	$arr = $imageDetails.split(':')
	$imageTag = [INT]$arr[1]
}

$workspace = (Get-Location).Path
Write-Host "[$scriptName] `$imageTag  : $imageTag"
Write-Host "[$scriptName] `$workspace : $workspace"

if (( $buildNumber ) -and (-not $command)) {
	$command = "automation\provisioning\runner.bat automation-solution\entrypoint.ps1 $buildNumber"
}

if ( $command ) {
	executeExpression "docker run --tty --volume ${workspace}\:C:/workspace ${imageName}:${imageTag} $command"
} else {
	executeExpression "docker run --tty --volume ${workspace}\:C:/workspace ${imageName}:${imageTag}"
}

Write-Host "`n[$scriptName] List and remove all stopped containers"
executeExpression "docker ps --filter `"status=exited`" -a"
executeExpression "docker rm (docker ps --filter `"status=exited`" -aq)"

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0