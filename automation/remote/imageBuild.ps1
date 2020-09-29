Param (
	[string]$id,
	[string]$BUILDNUMBER,
	[string]$containerImage,
	[string]$constructor,
	[string]$registryTag,
	[string]$optionalArgs
)

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression "$expression 2> `$null"
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch {
		Write-Host "[$scriptName][EXCEPTION] List exception and error array (if populated) and exit with LASTEXITCIDE 1112" -ForegroundColor Red
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

function executeRetry ($expression) {
	$exitCode = 1
	$wait = 10
	$retryMax = 3
	$retryCount = 0
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "[$retryCount] $expression"
		try {
			$output = Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
		} catch { Write-Host $_.Exception | format-list -force; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] Warning, message in `$error[0] = $error" ;$error.clear(); docker-compose logs }
	    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { $exitCode = $LASTEXITCODE; Write-Host "[$scriptName] `$lastExitCode = $exitCode" }
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, listing docker images and processes for diagnostics and exiting with `$LASTEXITCODE = $exitCode.`n"
				Write-Host "[$scriptName] docker images`n"
				docker images
				Write-Host "[$scriptName] `ndocker ps`n"
				docker ps
				exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
				Start-Sleep $wait
				$wait = $wait + $wait
			}
		}
    }
    return $output
}

$scriptName = 'imageBuild.ps1'
cmd /c "exit 0"
$error.clear()

Write-Host "`n[$scriptName] ---------- start ----------`n"
if ( $id ) {
	$id = $id.ToLower()
	Write-Host "[$scriptName]   id              : $id"
} else {
	Write-Host "[$scriptName]   id not supplied! Exit with LASTEXITCODE 1"
	exit 1
}

if ( $buildNumber ) { 
	Write-Host "[$scriptName]   BUILDNUMBER     : $BUILDNUMBER"
} else {
	# Use a simple text file (buildnumber.counter) for incrimental build number
	if ( Test-Path imagenumber.counter ) {
		$BUILDNUMBER = Get-Content imagenumber.counter
	} else {
		$BUILDNUMBER = 0
	}
	[int]$BUILDNUMBER = [convert]::ToInt32($BUILDNUMBER)
	if ( $ACTION -ne "deliveryonly" ) { # Do not incriment when just deploying
		$BUILDNUMBER += 1
	}
	Out-File imagenumber.counter -InputObject $BUILDNUMBER
	Write-Host "[$scriptName]   BUILDNUMBER     : $BUILDNUMBER (using locally generated counter)"
}

if ( $containerImage ) {
	if (($env:CONTAINER_IMAGE) -or ($CONTAINER_IMAGE)) {
		Write-Host "[$scriptName]   containerImage  : $containerImage"
		if ($env:CONTAINER_IMAGE) {
			Write-Host "[$scriptName]   CONTAINER_IMAGE : $env:CONTAINER_IMAGE (not changed as already set)"
		} else {
			$env:CONTAINER_IMAGE = $CONTAINER_IMAGE
			Write-Host "[$scriptName]   CONTAINER_IMAGE : $env:CONTAINER_IMAGE (loaded from `$CONTAINER_IMAGE)"
		}
	} else {
		$env:CONTAINER_IMAGE = $containerImage
		Write-Host "[$scriptName]   CONTAINER_IMAGE : $env:CONTAINER_IMAGE (set to `$containerImage)"
	}
} else {
	if (($env:CONTAINER_IMAGE) -or ($CONTAINER_IMAGE)) {
		Write-Host "[$scriptName]   containerImage  : $containerImage"
		if ($env:CONTAINER_IMAGE) {
			Write-Host "[$scriptName]   CONTAINER_IMAGE : $env:CONTAINER_IMAGE (containerImage not passed, using existing environment variable)"
		} else {
			$env:CONTAINER_IMAGE = $CONTAINER_IMAGE
			Write-Host "[$scriptName]   CONTAINER_IMAGE : $env:CONTAINER_IMAGE (containerImage not passed, loaded from `$CONTAINER_IMAGE)"
		}
	} else {
		Write-Host "[$scriptName][ERROR] containerImage not passed and neither `$env:CONTAINER_IMAGE nor `$CONTAINER_IMAGE set, exiting with `$LASTEXITCODE 6674"
		exit 6674
	}
}

# 2.2.0 extension to allow custom source directory
if ( $constructor ) {
	Write-Host "[$scriptName]   constructor     : $constructor"
} else {
	Write-Host "[$scriptName]   constructor     : (not supplied, will process all directories)"
}

# 2.2.0 Replaced optional persist parameter as extension for the support as integrated function
if ( $registryTag ) {
	Write-Host "[$scriptName]   registryTag     : $registryTag"
} else {
	Write-Host "[$scriptName]   registryTag     : (not supplied, push will not be attempted)"
}

if ( $optionalArgs ) {
	Write-Host "[$scriptName]   optionalArgs    : $optionalArgs"
} else {
	Write-Host "[$scriptName]   optionalArgs    : (not supplied, example '--memory 4g')"
}

Write-Host "[$scriptName]   pwd             : $(Get-Location)"
Write-Host "[$scriptName]   hostname        : $(hostname)"
Write-Host "[$scriptName]   whoami          : $(whoami)"
$workspace = $(Get-Location)
Write-Host "[$scriptName]   workspace       : ${workspace}`n"

$transient = "$env:TEMP\buildImage\${id}"

if ( Test-Path "${transient}" ) {
	if (Test-Path "${transient}" -PathType "Leaf") {
		Write-Host "${transient} already exists, but is not a directory, replacing as directory"
		executeExpression "rm ${transient} -Force -Confirm:`$false"
		executeExpression "Write-Host 'Created $(mkdir ${transient})'"
	} else {
		Write-Host "Build directory ${transient} already exists"
	}
} else {
	executeExpression "Write-Host 'Created $(mkdir ${transient})'"
}

if ( $constructor ) {
	$constructor = $constructor.Split()
} else {
	$constructor = Get-ChildItem -Path "." -directory
}
$constructor
foreach ($image in $constructor ) {
	Write-Host "`n----------------------"
	Write-Host "    ${image}"    
	Write-Host "----------------------`n"
	if ( Test-Path "${transient}\${image}" ) {
		executeExpression "rm -Recurse ${transient}\${image}"
	}
	executeExpression "cp -Recurse .\${image} ${transient}"
	if ( Test-Path ../dockerBuild.ps1 ) {
		executeExpression "cp ../dockerBuild.ps1 ${transient}\${image}"
	} else {
		executeExpression "cp $env:CDAF_AUTOMATION_ROOT/remote/dockerBuild.ps1 ${transient}\${image}"
	}
	if ( Test-Path ../dockerClean.ps1 ) {
		executeExpression "cp ../dockerClean.ps1 ${transient}\${image}"
	} else {
		executeExpression "cp $env:CDAF_AUTOMATION_ROOT/remote/dockerClean.ps1 ${transient}\${image}"
	}
	executeExpression "cp -Recurse ../automation ${transient}\${image}"
	executeExpression "cd ${transient}\${image}"
	executeExpression "cat Dockerfile"
	if ( $optionalArgs ) {
		executeExpression "./dockerBuild.ps1 ${id}_${image} $BUILDNUMBER -optionalArgs '${optionalArgs}'"
	} else {
		executeExpression "./dockerBuild.ps1 ${id}_${image} $BUILDNUMBER"
	}
	executeExpression "./dockerClean.ps1 ${id}_${image} $BUILDNUMBER"
	executeExpression "cd $workspace"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0