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
	executeExpression "docker login --username $registryUser --password `$registryToken $registryURL"
}

function REMOVE ($itemPath) { 
	if ( Test-Path $itemPath ) {
		write-host "[REMOVE] Remove-Item $itemPath -Recurse -Force"
		Remove-Item $itemPath -Recurse -Force
		if(!$?) { ERRMSG "[REMOVE] Remove-Item $itemPath -Recurse -Force Failed" 10006 }
	}
}

function MASKED ($value) {
	(Get-FileHash -InputStream $([IO.MemoryStream]::new([byte[]][char[]]$value)) -Algorithm SHA256).Hash
}

$scriptName = 'imageBuild.ps1'
cmd /c "exit 0"
$error.clear()

Write-Host "`n[$scriptName] ---------- start ----------"
if (!( $id )) {
	Write-Host "[$scriptName]   ID not supplied, will only attempt login"
} else {
	$id = $id.ToLower()
	$SOLUTION = ($id.Split('_'))[0]  # Use solution name for temp directory name
	Write-Host "[$scriptName]   id                  : $id"

	if (!( $buildNumber )) {

		Write-Host "[$scriptName]   BUILDNUMBER not supplied, will publish $id as latest"

	} else {
		Write-Host "[$scriptName]   BUILDNUMBER         : $BUILDNUMBER"

		if ( $containerImage ) {
			if ( $env:CONTAINER_IMAGE ) {
			    Write-Host "[$scriptName]   CONTAINER_IMAGE     : $containerImage (override environment variable $env:CONTAINER_IMAGE)"
			} else {
			    Write-Host "[$scriptName]   CONTAINER_IMAGE     : $containerImage"
			}
		} else {	
			if ( $env:CONTAINER_IMAGE ) {
			    Write-Host "[$scriptName]   CONTAINER_IMAGE     : $env:CONTAINER_IMAGE (loaded from environment variable)"
				$containerImage = "$env:CONTAINER_IMAGE"
			} else {
			    Write-Host "[$scriptName]   CONTAINER_IMAGE     : (not supplied)"
			}
		}

		# 2.2.0 Replaced optional persist parameter as extension for the support as integrated function, extension to allow custom source directory
		if ( $constructor ) {
			Write-Host "[$scriptName]   constructor         : $constructor"
		} else {
			Write-Host "[$scriptName]   constructor         : (not supplied, will process all directories)"
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
	}
}

if ( $env:CDAF_SKIP_PULL ) {
	Write-Host "[$scriptName]   CDAF_SKIP_PULL      : $env:CDAF_SKIP_PULL"
} else {
	Write-Host "[$scriptName]   CDAF_SKIP_PULL      : (not supplied)"
}

$manifest = "${WORKSPACE}\manifest.txt"
if ( ! ( Test-Path ${manifest} )) {
	echo "[$scriptName] Manifest not found ($manifest)!"
	exit 5343
}

$cdafRegistryURL = & "${env:CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_REGISTRY_URL"
if ( $cdafRegistryURL ) { $cdafRegistryURL = Invoke-Expression "Write-Output $cdafRegistryURL" }
if ( $cdafRegistryURL ) {
	if ( $env:CDAF_REGISTRY_URL ) {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_URL   : $cdafRegistryURL (loaded from manifest.txt, override environment variable $env:CDAF_REGISTRY_URL)"
	} else {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_URL   : $cdafRegistryURL (loaded from manifest.txt)"
	}
	$registryURL = "$cdafRegistryURL"
} else {	
	if ( $env:CDAF_REGISTRY_URL ) {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_URL   : $env:CDAF_REGISTRY_URL (loaded from environment variable)"
		$registryURL = "$env:CDAF_REGISTRY_URL"
	} else {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_URL   : (not supplied, do not set when pushing to Dockerhub)"
	}
}

$cdafRegistryUser = & "${env:CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_REGISTRY_USER"
if ( $cdafRegistryUser ) { $cdafRegistryUser = Invoke-Expression "Write-Output $cdafRegistryUser" }
if ( $cdafRegistryUser ) {
	if ( $env:CDAF_REGISTRY_USER ) {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_USER  : $cdafRegistryUser (loaded from manifest.txt, override environment variable $env:CDAF_REGISTRY_USER)"
	} else {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_USER  : $cdafRegistryUser (loaded from manifest.txt)"
	}
	$registryUser = "$cdafRegistryUser"
} else {	
	if ( $env:CDAF_REGISTRY_USER ) {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_USER  : $env:CDAF_REGISTRY_USER (loaded from environment variable)"
		$registryUser = "$env:CDAF_REGISTRY_USER"
	} else {
		$registryUser = '.'
	    Write-Host "[$scriptName]   CDAF_REGISTRY_USER  : $registryUser (not supplied, set to default)"
	}
}

$cdafRegistryToken = & "${env:CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_REGISTRY_TOKEN"
if ( $cdafRegistryToken ) { $cdafRegistryToken = Invoke-Expression "Write-Output $cdafRegistryToken" }
if ( $cdafRegistryToken ) {
	if ( $env:CDAF_REGISTRY_TOKEN ) {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_TOKEN : $(MASKED $cdafRegistryToken) (loaded from manifest.txt, override environment variable $(MASKED $env:CDAF_REGISTRY_TOKEN))"
	} else {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_TOKEN : $(MASKED $cdafRegistryToken) (loaded from manifest.txt)"
	}
	$registryToken = "$cdafRegistryToken"
} else {	
	if ( $env:CDAF_REGISTRY_TOKEN ) {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_TOKEN : $(MASKED $env:CDAF_REGISTRY_TOKEN) (loaded from environment variable)"
		$registryToken = "$env:CDAF_REGISTRY_TOKEN"
	} else {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_TOKEN : (not supplied, login and push will not be attempted)"
	}
}

$cdafRegistryTag = & "${env:CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_REGISTRY_TAG"
if ( $cdafRegistryTag ) { $cdafRegistryTag = Invoke-Expression "Write-Output $cdafRegistryTag" }
if ( $cdafRegistryTag ) {
	if ( $env:CDAF_REGISTRY_TAG ) {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_TAG   : $cdafRegistryTag (loaded from manifest.txt, override environment variable $env:CDAF_REGISTRY_TAG)`n"
	} else {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_TAG   : $cdafRegistryTag (loaded from manifest.txt)`n"
	}
	$registryTag = "$cdafRegistryTag"
} else {	
	if ( $env:CDAF_REGISTRY_TAG ) {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_TAG   : $env:CDAF_REGISTRY_TAG (loaded from environment variable)`n"
		$registryTag = "$env:CDAF_REGISTRY_TAG"
	} else {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_TAG   : (not supplied)`n"
	}
}

if (!( $id )) {

	if ( "$registryToken" ) {
		dockerLogin
	} else {
		Write-Host "[$scriptName]   CDAF_REGISTRY_TOKEN not set, skipping login"
	}

} else {

	if (!( $buildNumber )) {

		if ( "$registryToken" ) {
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
			Write-Host "[$scriptName]   CDAF_REGISTRY_TOKEN not set, skipping login and push"
		}

	} else {

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
				if ( $baseImage ) {
					executeExpression "./dockerBuild.ps1 ${id}_${image} $BUILDNUMBER -optionalArgs '${optionalArgs}' -baseImage '$containerImage'"
				} else {
					executeExpression "./dockerBuild.ps1 ${id}_${image} $BUILDNUMBER -optionalArgs '${optionalArgs}'"
				}
			} else {
				if ( $baseImage ) {
					executeExpression "./dockerBuild.ps1 ${id}_${image} $BUILDNUMBER -baseImage '$containerImage'"
				} else {
					executeExpression "./dockerBuild.ps1 ${id}_${image} $BUILDNUMBER"
				}
			}
			executeExpression "cd $workspace"
		}

		$pushFeatureBranch = & "${env:CDAF_CORE}\getProperty.ps1" "${manifest}" "pushFeatureBranch"
		if ( $pushFeatureBranch -ne 'yes' ) {
			$REVISION = & "${env:CDAF_CORE}\getProperty.ps1" "${manifest}" "REVISION"
			$defaultBranch = & "${env:CDAF_CORE}\getProperty.ps1" "${manifest}" "defaultBranch"
			if (!( $defaultBranch )) {
				$defaultBranch = 'master'
			}
			if ( $REVISION -ne $defaultBranch ) {
				Write-Host "Do not push feature branch, set pushFeatureBranch=yes to force push, clearing registryToken`n"
				$registryToken = ''
			}
		}

		# 2.2.0 Integrated Registry push, not masking of secrets, it is expected the CI tool will know to mask these
		if ( "$registryToken" ) {
			executeExpression "docker login --username $registryUser --password `$registryToken $registryURL"
			executeExpression "docker tag ${id}_${image}:$BUILDNUMBER $registryTag"
			executeExpression "docker push $registryTag"
		} else {
			Write-Host "CDAF_REGISTRY_TOKEN not set, to push to registry set CDAF_REGISTRY_URL, CDAF_REGISTRY_TAG, CDAF_REGISTRY_USER & CDAF_REGISTRY_TOKEN"
			Write-Host "Do not set CDAF_REGISTRY_URL when pushing to dockerhub"
		}
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0