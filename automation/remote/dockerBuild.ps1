Param (
	[string]$imageName,
	[string]$tag,
	[string]$version,
	[string]$rebuild
)

$scriptName = 'dockerBuild.ps1'

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
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception|format-list -force; exit 2 }
	$error.clear()
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] Suppress `$LASTEXITCODE ($LASTEXITCODE)"; cmd /c "exit 0" } # reset LASTEXITCODE
}

cmd /c "exit 0"

Write-Host "`n[$scriptName] ---------- start ----------"
Write-Host "`n[$scriptName] Build docker image, resulting image tag will be ${imageName}:${tag}"
if ($imageName) {
    Write-Host "[$scriptName] imageName : $imageName"
} else {
    Write-Host "[$scriptName] imageName not supplied, exit with `$LASTEXITCODE = 1"; exit 1
}
if ($tag) {
    Write-Host "[$scriptName] tag       : $tag"
} else {
    Write-Host "[$scriptName] tag       : not supplied"
}
if ($version) {
    Write-Host "[$scriptName] version   : $version"
} else {
	if ( $tag ) {
		$version = $tag
	} else {
		$version = '0.0.0'
	}
    Write-Host "[$scriptName] version   : $version (not supplied, defaulted to tag if passed, else set to 0.0.0)"
}
if ($rebuild) {
    Write-Host "[$scriptName] rebuild   : $rebuild"
} else {
    Write-Host "[$scriptName] rebuild   : (not supplied, docker will use cache where possible)"
}

Write-Host "`n[$scriptName] List existing images ...`n"
$imagesBefore = docker images -f label=cdaf.${imageName}.image.version
if ( $LASTEXITCODE -ne 0 ) {
	cmd /c "exit 0"
	Write-Host "`n[$scriptName] Attempting to start docker ...`n"
	executeExpression 'Start-Service Docker'
	executeExpression "docker images -f label=cdaf.${imageName}.image.version"
} else {
	Write-Host "docker images -f label=cdaf.${imageName}.image.version"
	$imagesBefore
}

Write-Host "`n[$scriptName] As of 1.13.0 new prune commands, if using older version, suppress error"
executeSuppress "docker system prune -f"

$buildCommand = 'docker build'

if ($env:http_proxy) {
	Write-Host "`n[$scriptName] `$env:http_proxy is set ($env:http_proxy), pass as `$proxy to build`n"
	$buildCommand += " --build-arg proxy=$env:http_proxy"
}

if ($rebuild -eq 'yes') {
	$buildCommand += " --no-cache=true"
}

if ($env:CONTAINER_IMAGE) {
	$buildCommand += " --build-arg CONTAINER_IMAGE=$env:CONTAINER_IMAGE"
}

if ($tag) {
	$buildCommand += " --tag ${imageName}:${tag}"
} else {
	$buildCommand += " --tag ${imageName} "
}

# Apply required label for CDAF image management
$buildCommand += " --label=cdaf.${imageName}.image.version=${version}"

# Execute the constucted build command using dockerfile from current directory (.)
executeExpression "$buildCommand ."

Write-Host "`n[$scriptName] List Resulting images...`n"
executeExpression "docker images -f label=cdaf.${imageName}.image.version"

Write-Host "`n[$scriptName] --- end ---"
$error.clear()
exit 0
