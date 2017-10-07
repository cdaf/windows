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
	$LASTEXITCODE = 0
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $LASTEXITCODE -ne 0 ) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
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
	# Use a simple text file (buildnumber.counter) for incrimental build number
	if ( Test-Path buildnumber.counter ) {
		$buildNumber = Get-Content buildnumber.counter
	} else {
		$buildNumber = 0
	}
	[int]$buildnumber = [convert]::ToInt32($buildNumber)
	if ( $ACTION -ne "deliveryonly" ) { # Do not incriment when just deploying
		$buildNumber += 1
	}
	Out-File buildnumber.counter -InputObject $buildNumber
	Write-Host "[$scriptName]   buildNumber  : $buildNumber (not passed so derived using buildnumber.counter file)"
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

$imageExists = (docker images --filter=label=cdaf.${imageName}.image.version -q)
if (!( $imageExists )) {
	Write-Host "[$scriptName] No build image exists, initialise (ignore `$rebuildImage)"
	$rebuildImage = 'yes'
}

if ( $rebuildImage -eq 'yes') {
	executeExpression "cat Dockerfile"
	
	# Do not execute using function as interactive logging stops working
	Write-Host "`n[$scriptName] automation/remote/dockerBuild.ps1 ${imageName} $buildNumber`n"
	$LASTEXITCODE = 0
	automation/remote/dockerBuild.ps1 ${imageName} $buildNumber
	if ( $LASTEXITCODE -ne 0 ) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }

	# Remove any older images	
	Write-Host "`n[$scriptName] automation/remote/dockerClean.ps1 ${imageName} $buildNumber"
	$LASTEXITCODE = 0
	automation/remote/dockerClean.ps1 ${imageName} $buildNumber
	if ( $LASTEXITCODE -ne 0 ) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

# There should always be only 1 image
executeExpression "docker images --filter=label=cdaf.${imageName}.image.version"
$imageID = (docker images --filter=label=cdaf.${imageName}.image.version -q)

if ( $command ) {
	executeExpression "docker run --tty --volume $(pwd):C:/workspace $imageID `"$command`""
} else {
	executeExpression "docker run --tty --volume $(pwd):C:/workspace $imageID"
}
executeExpression "docker rm (docker ps -aq)"

Write-Host "`n[$scriptName] ---------- stop ----------"
