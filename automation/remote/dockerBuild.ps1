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
    Write-Host "[$scriptName] imageName not supplied, exit with `$LASTEXITCODE = 1"; exit 1
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

$cdafRegistryPullURL = & "${env:CDAF_CORE}\getProperty.ps1" "$WORKSPACE\manifest.txt" "CDAF_PULL_REGISTRY_URL"
if ( $cdafRegistryPullURL ) {
	$cdafRegistryPullURL = Invoke-Expression "Write-Output $cdafRegistryPullURL"
	if ( $env:CDAF_PULL_REGISTRY_URL ) {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_URL   : $cdafRegistryPullURL (loaded from manifest.txt, override environment variable $env:CDAF_PULL_REGISTRY_URL)"
	} else {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_URL   : $cdafRegistryPullURL (loaded from manifest.txt)"
	}
	$registryPullURL = "$cdafRegistryPullURL"
} else {	
	if ( $env:CDAF_PULL_REGISTRY_URL ) {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_URL   : $env:CDAF_PULL_REGISTRY_URL (loaded from environment variable)"
		$registryPullURL = "$env:CDAF_PULL_REGISTRY_URL"
	} else {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_URL   : (not supplied, do not set when pulling from Dockerhub)"
	}
}

$cdafRegistryPullUser = & "${env:CDAF_CORE}\getProperty.ps1" "$WORKSPACE\manifest.txt" "CDAF_PULL_REGISTRY_USER"
if ( $cdafRegistryPullUser ) {
	$cdafRegistryPullUser = Invoke-Expression "Write-Output $cdafRegistryPullUser"
	if ( $env:CDAF_PULL_REGISTRY_USER ) {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_USER  : $cdafRegistryPullUser (loaded from manifest.txt, override environment variable $CDAF_PULL_REGISTRY_USER)"
	} else {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_USER  : $cdafRegistryPullUser (loaded from manifest.txt)"
	}
	$registryPullUser = "$cdafRegistryPullUser"
} else {	
	if ( $env:CDAF_PULL_REGISTRY_USER ) {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_USER  : $env:CDAF_PULL_REGISTRY_USER (loaded from environment variable)"
		$registryPullUser = "$env:CDAF_PULL_REGISTRY_USER"
	} else {
		$registryPullUser = '.'
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_USER  : $registryPullUser (not supplied, set to default)"
	}
}

$cdafRegistryPullToken = & "${env:CDAF_CORE}\getProperty.ps1" "$WORKSPACE\manifest.txt" "CDAF_PULL_REGISTRY_TOKEN"
if ( $cdafRegistryPullToken ) {
	$cdafRegistryPullToken = Invoke-Expression "Write-Output $cdafRegistryPullToken"
	if ( $env:CDAF_PULL_REGISTRY_TOKEN ) {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_TOKEN : $(MASKED $cdafRegistryPullToken) (loaded from manifest.txt, override environment variable $(MASKED $env:CDAF_PULL_REGISTRY_TOKEN))"
	} else {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_TOKEN : $(MASKED $cdafRegistryPullToken) (loaded from manifest.txt)"
	}
	$registryPullToken = "$cdafRegistryPullToken"
} else {	
	if ( $env:CDAF_PULL_REGISTRY_TOKEN ) {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_TOKEN : $(MASKED $env:CDAF_PULL_REGISTRY_TOKEN) (loaded from environment variable)"
		$registryPullToken = "$env:CDAF_PULL_REGISTRY_TOKEN"
	} else {
	    Write-Host "[$scriptName] CDAF_PULL_REGISTRY_TOKEN : (not supplied, login will not be attempted)"
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

	if ( $env:CDAF_SKIP_PULL -ne 'yes' ) {
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
