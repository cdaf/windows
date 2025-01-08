Param (
    [string]$imageName,
    [string]$dockerExpose,
    [string]$publishedPort,
    [string]$tag,
    [string]$environment,
    [string]$registry,
    [string]$dockerOpt
)

cmd /c "exit 0"
$scriptName = 'dockerRun.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

if ($dockerExpose) {
    Write-Host "`n[$scriptName] Start a container instance, if an existing instance (based on image and port) is running, it will be replaced."
}

Write-Host "`n[$scriptName] --- start ---"
if ($imageName) {
	$imageName = $imageName.ToLower()
    Write-Host "[$scriptName] imageName     : $imageName"
} else {
    Write-Host "[$scriptName] imageName not supplied, exit with `$LASTEXITCODE = 1"; exit 1
}

# 2.4.0 Centralise docker operations by supporting implicit clean function
if (!($dockerExpose)) {
    Write-Host "[$scriptName] dockerExpose  : (not supplied, will only clean running containers)"
} else {
    Write-Host "[$scriptName] dockerExpose  : $dockerExpose"
    if ($publishedPort) {
        Write-Host "[$scriptName] publishedPort : $publishedPort"
    } else {
        $publishedPort = '80'
        Write-Host "[$scriptName] publishedPort : $publishedPort (default)"
    }
    
    if ($tag) {
        Write-Host "[$scriptName] tag           : $tag"
    } else {
        $tag = 'latest'
        Write-Host "[$scriptName] tag           : $tag (default)"
    }
    
    if ($environment) {
        Write-Host "[$scriptName] environment   : $environment"
    } else {
        $environment = $tag
        Write-Host "[$scriptName] environment   : $environment (not passed, set to same value as tag)"
    }
    
    if ($registry) {
        Write-Host "[$scriptName] registry      : $registry"
    } else {
        Write-Host "[$scriptName] registry      : not passed, use local repo"
    }
    
    if ($dockerOpt) {
        Write-Host "[$scriptName] dockerOpt     : $dockerOpt"
    } else {
        Write-Host "[$scriptName] dockerOpt     : not passed, e.g. --restart unless-stopped"
    }
}

Write-Host "`n[$scriptName] List version for logging purposes`n"
executeExpression "docker --version"

if ($dockerExpose) {
    Write-Host "`n[$scriptName] Globally unique label, based on port, if in use, stop and remove`n"
    $instance = "${imageName}:${publishedPort}"
    Write-Host "[$scriptName] `$instance = $instance (container ID)"
}

Write-Host "`n[$scriptName] List the running containers (before)`n"
docker ps

if ($dockerExpose) {
	Write-Host "`n[$scriptName] Remove any existing containers based on docker ps --filter label=cdaf.${imageName}.container.instance=${instance}`n"
	foreach ($containerInstance in docker ps --filter label=cdaf.${imageName}.container.instance=${instance} -aq) {
		Write-Host "[$scriptName] Stop and remove existing container instance ($instance)"
		executeExpression "docker stop $containerInstance"
		executeExpression "docker rm $containerInstance"
	}
} else {
	Write-Host "`n[$scriptName] Remove any existing containers based on docker ps --filter label=cdaf.${imageName}.container.instance`n"
	foreach ($containerInstance in docker ps --filter label=cdaf.${imageName}.container.instance -aq) {
		Write-Host "[$scriptName] Stop and remove existing container instance ($instance)"
		executeExpression "docker stop $containerInstance"
		executeExpression "docker rm $containerInstance"
	}
}

if ($dockerExpose) {
    # Use the image name and published port as the unique identifier on the host 
    $dockerCommand = "docker run --detach --publish '${publishedPort}:${dockerExpose}' --name '${imageName}_${publishedPort}'" 

    # Include any optional arguments, e.g. --restart=always
    $dockerCommand += " $dockerOpt"

    # Apply container labels (additive to the build labels) for filter purposes, only unique ID above is important in run context
    $dockerCommand += " --label 'cdaf.${imageName}.container.instance=$instance' --label 'cdaf.${imageName}.container.environment=$environment'"

    # Finall determine if a registry is in use 
    if ( $registry ) {
        $dockerCommand += " ${registry}/${imageName}:${tag}"
    } else {
        $dockerCommand += " ${imageName}:${tag}"
    }

    Write-Host "`n[$scriptName] Start container`n"
    executeExpression "$dockerCommand"
}

Write-Host "`n[$scriptName] List the running containers (after)"
docker ps

Write-Host "`n[$scriptName] --- end ---`n"
$error.clear()
exit 0
