Param (
  [string]$imageName,
  [string]$tag
)
# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if ( $lastExitCode -ne 0 ) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode "; exit $lastExitCode }
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeSuppress ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?" }
	} catch { Write-Host $_.Exception|format-list -force }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error" }
    if ( $lastExitCode -ne 0 ) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode " }
}

$scriptName = 'dockerClean.ps1'
Write-Host "`n[$scriptName] Clean image from registry based on Product label. If a tag is passed,"
Write-Host "[$scriptName] only images with a tag value less that the one supplied and removed."
Write-Host "`n[$scriptName] --- start ---"
if ($imageName) {
    Write-Host "[$scriptName] imageName : $imageName"
} else {
    Write-Host "[$scriptName] imageName not supplied, exit with `$LASTEXITCODE = 1"; exit 1
}

if ($tag) {
    Write-Host "[$scriptName] tag       : $tag"
} else {
    Write-Host "[$scriptName] tag not supplied, all will be removed."
}

Write-Host "`n[$scriptName] List images (before)"
executeExpression "docker images"

Write-Host "`n[$scriptName] Remove untagged orphaned (dangling) images"
foreach ($imageID in docker images -aq -f dangling=true) {
	executeSuppress "docker rmi $imageID"
}

Write-Host "`n[$scriptName] Remove unused images (ignore failures). This process relies on the dockerBuild process where docker image label holds the product version."
Write-Host "[$scriptName]   docker images --filter label=cdaf.${imageName}.image.version -a"
Write-Host "[$scriptName]   Note: the version value itself is ignored and is for information purposes only."
foreach ( $imageDetails in docker images --filter label=cdaf.${imageName}.image.version --format "{{.ID}}:{{.Tag}}" ) {
	$arr = $imageDetails.split(':')
	$imageID = $arr[0]
	$imageTag = $arr[1]
	if ( $tag ) {
		if ( $imageTag -lt $tag ) {
			Write-Host "[$scriptName] Remove Image $imageDetails"
			executeSuppress "docker rmi $imageID"
		}
	} else {
		Write-Host "[$scriptName] Remove All, Image $imageDetails"
		executeSuppress "docker rmi $imageID"
	}
}	

Write-Host "`n[$scriptName] List images (after)"
executeExpression "docker images"

Write-Host "`n[$scriptName] --- end ---"
