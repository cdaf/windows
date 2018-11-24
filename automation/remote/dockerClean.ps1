Param (
  [string]$imageName,
  [string]$tag
)

cmd /c "exit 0"
$scriptName = 'dockerClean.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeSuppress ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception|format-list -force; exit 2 }
	$error.clear()
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] Suppress `$LASTEXITCODE ($LASTEXITCODE)"; cmd /c "exit 0" } # reset LASTEXITCODE
}

Write-Host "`n[$scriptName] Clean image from registry based on Product label. If a tag is passed, only images with a tag value less that the one supplied are removed."
Write-Host "`n[$scriptName] --- start ---"
if ($imageName) {
    Write-Host "[$scriptName] imageName : $imageName"
} else {
    Write-Host "[$scriptName] imageName not supplied, will only clean containers"
}

if ($tag) {
    Write-Host "[$scriptName] tag       : $tag"
} else {
    Write-Host "[$scriptName] tag not supplied, all will be removed (unless no image supplied)"
}

Write-Host "`n[$scriptName] List images (before)"
executeExpression "docker images"

Write-Host "`n[$scriptName] As of 1.13.0 new prune commands, if using older version, suppress error"
executeSuppress "docker system prune -f"

Write-Host "`n[$scriptName] List stopped containers"
executeExpression "docker ps --filter `"status=exited`" -a"

$stoppedIDs = docker ps --filter "status=exited" -aq
if ($stoppedIDs) {
	Write-Host "`n[$scriptName] Remove stopped containers"
	executeSuppress "docker rm $stoppedIDs"
}

Write-Host "`n[$scriptName] Remove untagged orphaned (dangling) images"
foreach ($imageID in docker images -aq -f dangling=true) {
	executeSuppress "docker rmi -f $imageID"
}

if ($imageName) {
	Write-Host "`n[$scriptName] Remove unused images (ignore failures). This process relies on the dockerBuild process where docker image label holds the product version."
	Write-Host "[$scriptName]   docker images --filter label=cdaf.${imageName}.image.version -a"
	Write-Host "[$scriptName]   Note: the version value itself is ignored and is for information purposes only."
	foreach ( $imageDetails in docker images --filter label=cdaf.${imageName}.image.version --format "{{.ID}}:{{.Tag}}:{{.Repository}}" ) {
		$arr = $imageDetails.split(':')
		$imageID = $arr[0]
		$imageTag = [INT]$arr[1]
		$Repository = $arr[2]
		if ( $tag ) {
			if ( $imageTag -lt $tag ) {
				Write-Host "[$scriptName]   Remove Image $imageDetails for repository $Repository"
				executeSuppress "docker rmi -f $imageID"
			} else {
				# image clean logic is based on promotion pipeline, i.e. Test --> Staging --> Prod, and this would be run only after prod,
				# with the expectation that the last stage (Prod) will have the oldest supported version (tag) at any time.
				Write-Host "[$scriptName]   Image $imageTag is equal to or greater than $tag, perform no action (for repository $Repository)"
			}
		} else {
			Write-Host "[$scriptName]   Remove All, Image $imageDetails"
			executeSuppress "docker rmi -f $imageID"
		}
	}	
}

Write-Host "`n[$scriptName] List images (after)"
executeExpression "docker images"

Write-Host "`n[$scriptName] --- end ---"
$error.clear()
exit 0
