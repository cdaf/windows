Param (
	[string]$imageName,
	[string]$tag,
	[string]$version,
	[string]$rebuild,
	[string]$optionalArgs,
	[string]$baseImage
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

function MASKED ($value) {
	(Get-FileHash -InputStream $([IO.MemoryStream]::new([byte[]][char[]]$value)) -Algorithm SHA256).Hash
}

$scriptName = 'dockerBuild.ps1'
$Error.clear()
cmd /c "exit 0"

Write-Host "`n[$scriptName] Build docker image, resulting image tag will be ${imageName}:${tag}"
Write-Host "`n[$scriptName] ---------- start ----------"
if ( $imageName ) {
	$imageName = $imageName.ToLower()
    Write-Host "[$scriptName] imageName                : $imageName"
} else {
    Write-Host "[$scriptName] imageName not supplied, exit with `$LASTEXITCODE = 1"; exit 1111
}

if ( $tag ) {
    Write-Host "[$scriptName] tag                      : $tag"
} else {
    Write-Host "[$scriptName] tag                      : not supplied"
}

if ( $version ) {
    Write-Host "[$scriptName] version                  : $version"
} else {
	if ( $tag ) {
		$version = $tag
	} else {
		$version = '0.0.0'
	}
    Write-Host "[$scriptName] version                  : $version (not supplied, defaulted to tag if passed, else set to 0.0.0)"
}

if ( $rebuild ) {
    Write-Host "[$scriptName] rebuild                  : $rebuild"
} else {
    Write-Host "[$scriptName] rebuild                  : (not supplied, docker will use cache where possible)"
}

if ( $optionalArgs ) {
    Write-Host "[$scriptName] optionalArgs             : $optionalArgs"
} else {
    Write-Host "[$scriptName] optionalArgs             : (not supplied)"
}

if ( $baseImage ) {
	if ( $env:CONTAINER_IMAGE ) {
	    Write-Host "[$scriptName] baseImage                : $baseImage (override environment variable $CONTAINER_IMAGE)"
	} else {
	    Write-Host "[$scriptName] baseImage                : $baseImage"
	}
	$containerImage = "$baseImage"
} else {	
	if ( $env:CONTAINER_IMAGE ) {
	    Write-Host "[$scriptName] CONTAINER_IMAGE          : $env:CONTAINER_IMAGE (loaded from environment variable)"
		$containerImage = "$env:CONTAINER_IMAGE"
	} else {
	    Write-Host "[$scriptName] CONTAINER_IMAGE          : (not supplied)"
	}
}

# 2.6.0 Image from Private Registry
$manifest = "${env:WORKSPACE}\manifest.txt"
if ( ! ( Test-Path ${manifest} )) {
	echo "[$scriptName] Manifest not found ($manifest)!"
	exit 1114
}

if ( $env:CDAF_PULL_REGISTRY_URL ) {
	$registryPullURL = "$env:CDAF_PULL_REGISTRY_URL"
    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_URL   : $registryPullURL (loaded from environment variable)"
} else {
	$registryPullURL = & "${env:CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_PULL_REGISTRY_URL"
	if ( $registryPullURL ) { $registryPullURL = Invoke-Expression "Write-Output $registryPullURL"
	if ( $registryPullURL ) {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_URL   : $registryPullURL (loaded from manifest.txt)"
	} else {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_URL   : (not supplied, do not set when pulling from Dockerhub)"
	}
}

if ( $env:CDAF_PULL_REGISTRY_USER ) {
	$registryPullUser = "$env:CDAF_PULL_REGISTRY_USER"
    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_USER  : $registryPullUser (loaded from environment variable)"
} else {
	$registryPullUser = & "${env:CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_PULL_REGISTRY_USER"
	if ( $registryPullUser ) { $registryPullUser = Invoke-Expression "Write-Output $registryPullUser" }
	if ( $registryPullUser ) {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_USER  : $registryPullUser (loaded from manifest.txt)"
	} else {	
		$registryPullUser = '.'
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_USER  : $registryPullUser (not supplied, set to default)"
	}
}

if ( $env:CDAF_PULL_REGISTRY_TOKEN ) {
	$registryPullToken = "$env:CDAF_PULL_REGISTRY_TOKEN"
    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_TOKEN : $(MASKED $registryPullToken) (loaded from environment variable)"
} else {	
	$registryPullToken = & "${env:CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_PULL_REGISTRY_TOKEN"
	if ( $registryPullToken ) { $registryPullToken = Invoke-Expression "Write-Output $registryPullToken" }
	if ( $registryPullToken ) {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_TOKEN : $(MASKED $registryPullToken) (loaded from manifest.txt)"
	} else {	
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_TOKEN : (not supplied, login will not be attempted)"
	}
}

if ( $env:CDAF_SKIP_PULL ) {
	$skipPull = "$env:CDAF_SKIP_PULL"
    Write-Host "[$scriptName] CDAF_SKIP_PULL           : $skipPull (loaded from environment variable)"
} else {	
	$skipPull = & "${env:CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_SKIP_PULL"
	if ( $skipPull ) { $skipPull = Invoke-Expression "Write-Output $skipPull" }
	if ( $skipPull ) {
	    Write-Host "[$scriptName] CDAF_SKIP_PULL           : $skipPull (loaded from manifest.txt)"
	} else {
		skipPull='no'
	    Write-Host "[$scriptName] CDAF_SKIP_PULL           : $skipPull (default)"
	}
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

foreach ( $envVar in Get-ChildItem env:) {
	if ($envVar.Name.Contains('CDAF_IB_')) {
		${buildCommand} += " --build-arg $(${envVar}.Name.Replace('CDAF_IB_', ''))=$(${envVar}.Value)"
	}
}

if ($rebuild -eq 'yes') {
	$buildCommand += " --no-cache=true"
}

if ( $optionalArgs ) {
	$buildCommand += " $optionalArgs"
}

if ( $registryPullToken ) {
	Write-Host "`n[$scriptName] CDAF_PULL_REGISTRY_TOKEN set, attempt login..."
	executeExpression "docker login --username $registryPullUser --password `$registryPullToken $registryPullURL"
}

if ( $containerImage ) {
	$buildCommand += " --build-arg CONTAINER_IMAGE=$containerImage"

	if ( $skipPull -ne 'yes' ) {
	    executeExpression "docker pull $containerImage"
	}
}

if ($tag) {
	$buildCommand += " --tag ${imageName}:${tag}"
} else {
	$buildCommand += " --tag ${imageName} "
}

# Apply required label for CDAF image management
$buildCommand += " --label=cdaf.${imageName}.image.version=${version}"

# Execute the constucted build command using dockerfile from current directory (.)
$env:PROGRESS_NO_TRUNC = '1'
executeExpression "$buildCommand ."

Write-Host "`n[$scriptName] List Resulting images...`n"
executeExpression "docker images -f label=cdaf.${imageName}.image.version"

Write-Host "`n[$scriptName] --- end ---"
