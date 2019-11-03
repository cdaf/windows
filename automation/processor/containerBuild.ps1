Param (
	[string]$imageName,
	[string]$buildNumber,
	[string]$revision,
	[string]$action,
	[string]$rebuildImage
)

$scriptName = 'containerBuild.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Output $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

cmd /c "exit 0"
# Use the CDAF provisioning helpers
Write-Host "`n[$scriptName] ---------- start ----------`n"
if ( $imageName ) {
	Write-Host "[$scriptName]   imageName    : ${imageName} (passed)"
	Write-Host "[$scriptName]   imageName    : ${imageName} (to be used in docker)"
} else {
	Write-Host "[$scriptName]   imageName not supplied, exit with code 99"; exit 99
}

if ( $buildNumber ) { 
	Write-Host "[$scriptName]   buildNumber  : $buildNumber"
} else {
	Write-Host "[$scriptName]   buildNumber  : (not supplied)"
}

if ( $revision ) { 
	Write-Host "[$scriptName]   revision     : $revision"
} else {
	$revision = 'container_build'
	Write-Host "[$scriptName]   revision     : $revision (not supplied, set to default)"
}

if ( $action ) { 
	Write-Host "[$scriptName]   action       : $action"
} else {
	$action = 'containerbuild'
	Write-Host "[$scriptName]   action       : $action (not supplied, set to default)"
}

if ( $rebuildImage ) {
	Write-Host "[$scriptName]   rebuildImage : $rebuildImage (choices are yes, no or imageonly)"
} else {
	$rebuildImage = 'no'
	Write-Host "[$scriptName]   rebuildImage : $rebuildImage (not supplied, so set to default)"
}

$imageName = "${imageName}_$($revision.ToLower())"
Write-Host "[$scriptName]   imageName    : $imageName"
Write-Host "[$scriptName]   DOCKER_HOST  : $env:DOCKER_HOST"
Write-Host "[$scriptName]   pwd          : $(Get-Location)"
Write-Host "[$scriptName]   hostname     : $(hostname)"
Write-Host "[$scriptName]   whoami       : $(whoami)"
Write-Host '$dockerStatus = ' -NoNewline 

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
	
	executeExpression "docker run --tty --volume ${workspace}\:C:/solution/workspace ${imageName}:${imageTag} automation\processor\buildPackage.bat $buildNumber $revision $action"
	
	Write-Host "`n[$scriptName] List and remove all stopped containers"
	executeExpression "docker ps --filter `"status=exited`" -a"
	$stopped = docker ps --filter "status=exited" -aq
	if ( $stopped ) { 
		executeExpression "docker rm $stopped"
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0
