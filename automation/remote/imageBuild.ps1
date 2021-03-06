Param (
	[string]$id,
	[string]$BUILDNUMBER,
	[string]$containerImage,
	[string]$constructor,
	[string]$optionalArgs
)

function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Red
	} else {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Yellow
	}
	if ( $error ) {
		$i = 0
		foreach ( $item in $Error )
		{
			Write-Host "`$Error[$i] $item"
			$i++
		}
		$Error.clear()
	}
	if ( $env:CDAF_ERROR_DIAG ) {
		Write-Host "`n[$scriptName] Invoke custom diag `$env:CDAF_ERROR_DIAG = $env:CDAF_ERROR_DIAG`n"
		Invoke-Expression $env:CDAF_ERROR_DIAG
	}
	if ( $exitcode ) {
		Write-Host "`n[$scriptName] Exit with LASTEXITCODE = $exitcode`n" -ForegroundColor Red
		exit $exitcode
	}
}

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

function dockerLogin {
	if ( Test-Path manifest.txt ) {
		Write-Host "`n[$scriptName] Loading registry properties from manifest.txt..."
	} else {
		Write-Host "`n[$scriptName] manifest.txt file not found! If processing from CI context, use wrap.tsk driver.`n"
		exit 6630
	}

	$value = & .\getProperty.ps1 "manifest.txt" "CDAF_REGISTRY_URL"
	if ( $value ) {
		$env:CDAF_REGISTRY_URL = Invoke-Expression "Write-Output $value"
	}
	if ( $env:CDAF_REGISTRY_URL ) {
		Write-Host  "[$scriptName]  CDAF_REGISTRY_URL   = $env:CDAF_REGISTRY_URL"
	} else {
		Write-Host  "[$scriptName]  CDAF_REGISTRY_URL   = (not supplied, do not set when pushing to Dockerhub)"
	}

	$value = & .\getProperty.ps1 "manifest.txt" "CDAF_REGISTRY_USER"
	if ( $value ) {
		$env:CDAF_REGISTRY_USER = Invoke-Expression "Write-Output $value"
	}
	if ( $env:CDAF_REGISTRY_USER ) {
		Write-Host  "[$scriptName]  CDAF_REGISTRY_USER  = $env:CDAF_REGISTRY_USER"
	} else {
		Write-Host  "[$scriptName]  CDAF_REGISTRY_USER not supplied! User credentials required for publishing."
		exit 6631
	}

	$value = & .\getProperty.ps1 "manifest.txt" "CDAF_REGISTRY_TOKEN"
	if ( $value ) {
		$env:CDAF_REGISTRY_TOKEN = Invoke-Expression "Write-Output $value"
	}
	if ( $env:CDAF_REGISTRY_TOKEN ) {
		Write-Host  "[$scriptName]  CDAF_REGISTRY_TOKEN = $env:CDAF_REGISTRY_TOKEN"
	} else {
		Write-Host  "[$scriptName]  CDAF_REGISTRY_TOKEN not supplied! User credentials required for publishing."
		exit 6632
	}

	executeExpression "echo `$env:CDAF_REGISTRY_TOKEN | docker login --username $env:CDAF_REGISTRY_USER --password-stdin $env:CDAF_REGISTRY_URL"
}

function REMOVE ($itemPath) { 
	if ( Test-Path $itemPath ) {
		write-host "[REMOVE] Remove-Item $itemPath -Recurse -Force"
		Remove-Item $itemPath -Recurse -Force
		if(!$?) { ERRMSG "[REMOVE] Remove-Item $itemPath -Recurse -Force Failed" 10006 }
	}
}
	
$scriptName = 'imageBuild.ps1'
cmd /c "exit 0"
$error.clear()

Write-Host "`n[$scriptName] ---------- start ----------"
if (!( $id )) {
	dockerLogin
} else {
	$id = $id.ToLower()
	$SOLUTION = ($id.Split('_'))[0]  # Use solution name for temp directory name
	Write-Host "[$scriptName]   id                  : $id"

	if (!( $buildNumber )) {

		Write-Host "[$scriptName]   BUILDNUMBER not supplied, will publish $id as latest"
		dockerLogin
		$noTag,$tag = ${id}.Split(':')
		if ( $env:CDAF_REGISTRY_URL ) {
			executeExpression "docker tag $env:CDAF_REGISTRY_URL/${id} $env:CDAF_REGISTRY_URL/${noTag}:latest"
			executeExpression "docker push $env:CDAF_REGISTRY_URL/${noTag}:latest"
		} else {
			executeExpression "docker tag ${id} ${noTag}:latest"
			executeExpression "docker push ${noTag}:latest"
		}

	} else {
		Write-Host "[$scriptName]   BUILDNUMBER         : $BUILDNUMBER"

		if ( $containerImage ) {
			if (($env:CONTAINER_IMAGE) -or ($CONTAINER_IMAGE)) {
				Write-Host "[$scriptName]   containerImage      : $containerImage"
				if ($env:CONTAINER_IMAGE) {
					Write-Host "[$scriptName]   CONTAINER_IMAGE     : $env:CONTAINER_IMAGE (not changed as already set)"
				} else {
					$env:CONTAINER_IMAGE = $CONTAINER_IMAGE
					Write-Host "[$scriptName]   CONTAINER_IMAGE     : $env:CONTAINER_IMAGE (loaded from `$CONTAINER_IMAGE)"
				}
			} else {
				$env:CONTAINER_IMAGE = $containerImage
				Write-Host "[$scriptName]   CONTAINER_IMAGE     : $env:CONTAINER_IMAGE (set to `$containerImage)"
			}
		} else {
			if (($env:CONTAINER_IMAGE) -or ($CONTAINER_IMAGE)) {
				Write-Host "[$scriptName]   containerImage      : $containerImage"
				if ($env:CONTAINER_IMAGE) {
					Write-Host "[$scriptName]   CONTAINER_IMAGE     : $env:CONTAINER_IMAGE (containerImage not passed, using existing environment variable)"
				} else {
					$env:CONTAINER_IMAGE = $CONTAINER_IMAGE
					Write-Host "[$scriptName]   CONTAINER_IMAGE     : $env:CONTAINER_IMAGE (containerImage not passed, loaded from `$CONTAINER_IMAGE)"
				}
			} else {
				Write-Host "[$scriptName][ERROR] containerImage not passed and neither `$env:CONTAINER_IMAGE nor `$CONTAINER_IMAGE set, exiting with `$LASTEXITCODE 6674"
				exit 6674
			}
		}

		# 2.2.0 Replaced optional persist parameter as extension for the support as integrated function, extension to allow custom source directory
		if ( $constructor ) {
			Write-Host "[$scriptName]   constructor         : $constructor"
		} else {
			Write-Host "[$scriptName]   constructor         : (not supplied, will process all directories)"
		}

		if ( $env:CDAF_REGISTRY_URL ) {
			Write-Host "[$scriptName]   CDAF_REGISTRY_URL   : $env:CDAF_REGISTRY_URL"
		} else {
			Write-Host "[$scriptName]   CDAF_REGISTRY_URL   : (not supplied)"
		}

		if ( $env:CDAF_REGISTRY_TAG ) {
			Write-Host "[$scriptName]   CDAF_REGISTRY_TAG   : $env:CDAF_REGISTRY_TAG"
		} else {
			Write-Host "[$scriptName]   CDAF_REGISTRY_TAG   : (not supplied)"
		}

		if ( $env:CDAF_REGISTRY_USER ) {
			Write-Host "[$scriptName]   CDAF_REGISTRY_USER  : $env:CDAF_REGISTRY_USER"
		} else {
			Write-Host "[$scriptName]   CDAF_REGISTRY_USER  : (not supplied, push will not be attempted)"
		}

		if ( $env:CDAF_REGISTRY_TOKEN ) {
			Write-Host "[$scriptName]   CDAF_REGISTRY_TOKEN : $env:CDAF_REGISTRY_TOKEN"
		} else {
			Write-Host "[$scriptName]   CDAF_REGISTRY_TOKEN : (not supplied)"
		}

		if ( $optionalArgs ) {
			Write-Host "[$scriptName]   optionalArgs        : $optionalArgs"
		} else {
			Write-Host "[$scriptName]   optionalArgs        : (not supplied, example '--memory 4g')"
		}

		Write-Host "[$scriptName]   pwd                 : $(Get-Location)"
		Write-Host "[$scriptName]   hostname            : $(hostname)"
		Write-Host "[$scriptName]   whoami              : $(whoami)"
		$workspace = $(Get-Location)
		Write-Host "[$scriptName]   workspace           : ${workspace}`n"

		$transient = "$env:TEMP\${SOLUTION}\${id}"

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
			[array]$constructor = @((Get-ChildItem -Path "." -directory).Name)
		}
		foreach ($image in $constructor ) {
			Write-Host "`n----------------------"
			Write-Host "    ${image}"    
			Write-Host "----------------------`n"
			if ( Test-Path "${transient}\${image}" ) {
				executeExpression "REMOVE ${transient}\${image}"
			}
			executeExpression "cp -Recurse .\${image} ${transient}"
			$image = $image.ToLower()
			if ( Test-Path ../automation ) {
				executeExpression "cp -Recurse ../automation ${transient}\${image}"
			} else {
				Write-Host "`n[$scriptName][WARN] CDAF not found in ../automation`n"
			}
			if ( Test-Path ../dockerBuild.ps1 ) {
				executeExpression "cp ../dockerBuild.ps1 ${transient}\${image}"
			} else {
				if ( $env:CDAF_AUTOMATION_ROOT ) {
					executeExpression "cp $env:CDAF_AUTOMATION_ROOT/remote/dockerBuild.ps1 ${transient}\${image}"
				} else {
					Write-Host "`n[$scriptName][ERROR] dockerBuild.ps1 not found in parent directory and `$env:CDAF_AUTOMATION_ROOT not set. ABORT with LASTEXITCODE 7401 `n"
					exit 7401
				}
			}
			executeExpression "cd ${transient}\${image}"
			executeExpression "cat Dockerfile"
			if ( $optionalArgs ) {
				executeExpression "./dockerBuild.ps1 ${id}_${image} $BUILDNUMBER -optionalArgs '${optionalArgs}'"
			} else {
				executeExpression "./dockerBuild.ps1 ${id}_${image} $BUILDNUMBER"
			}
			executeExpression "cd $workspace"
		}

		# 2.2.0 Integrated Registry push, not masking of secrets, it is expected the CI tool will know to mask these
		if ( "$env:CDAF_REGISTRY_USER" ) {
			executeExpression "echo $env:CDAF_REGISTRY_TOKEN | docker login --username $env:CDAF_REGISTRY_USER --password-stdin $env:CDAF_REGISTRY_URL"
			executeExpression "docker tag ${id}_${image}:$BUILDNUMBER $env:CDAF_REGISTRY_TAG"
			executeExpression "docker push $env:CDAF_REGISTRY_TAG"
		} else {
			Write-Host "`$env:CDAF_REGISTRY_USER not set, to push to registry set CDAF_REGISTRY_URL, CDAF_REGISTRY_TAG, CDAF_REGISTRY_USER & CDAF_REGISTRY_TOKEN"
			Write-Host "Do not set CDAF_REGISTRY_URL when pushing to dockerhub"
		}
	}

}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0