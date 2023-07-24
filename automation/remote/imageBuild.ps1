Param (
	[string]$id,
	[string]$BUILDNUMBER,
	[string]$baseImage,
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

# Windows Command Execution combining standard error and standard out, with only non-zero exit code triggering error
function EXECMD ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	cmd /c "$expression 2>&1"
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
		ERRMSG "[EXECMD][EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
	}
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

		if ( $baseImage ) {
		    Write-Host "[$scriptName]   baseImage           : $baseImage"
	    } else {
		    Write-Host "[$scriptName]   baseImage           : (not supplied)"
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

# 2.6.0 Push Private Registry
$manifest = "${WORKSPACE_ROOT}\manifest.txt"
if ( ! ( Test-Path ${manifest} )) {
	$manifest = "${SOLUTIONROOT}\CDAF.solution"
	if ( ! ( Test-Path ${manifest} )) {
		Write-Host "[$scriptName] Properties not found in ${WORKSPACE_ROOT}\manifest.txt or ${manifest}!"
		exit 5343
	}
}

# 2.6.0 CDAF Solution property support, with environment variable override.
if ( $env:CDAF_REGISTRY_URL ) {
	$registryURL = $env:CDAF_REGISTRY_URL
    Write-Host "[$scriptName]   CDAF_REGISTRY_URL   : $registryURL (loaded from environment variable)"
} else {	
	$registryURL = & "${CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_REGISTRY_URL"
	if ( $registryURL ) { $registryURL = Invoke-Expression "Write-Output $registryURL" }
	if ( $registryURL ) {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_URL   : $registryURL (loaded from manifest.txt)"
	} else {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_URL   : (not supplied, do not set when pushing to Dockerhub)"
	}
}

if ( $env:CDAF_REGISTRY_USER ) {
	$registryUser = "$env:CDAF_REGISTRY_USER"
    Write-Host "[$scriptName]   CDAF_REGISTRY_USER  : $registryUser (loaded from environment variable)"
} else {
	$registryUser = & "${CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_REGISTRY_USER"
	if ( $registryUser ) { $registryUser = Invoke-Expression "Write-Output $registryUser" }
	if ( $registryUser ) {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_USER  : $registryUser (loaded from manifest.txt)"
	} else {	
		$registryUser = '.'
	    Write-Host "[$scriptName]   CDAF_REGISTRY_USER  : $registryUser (not supplied, set to default)"
	}
}

if ( $env:CDAF_REGISTRY_TOKEN ) {
	$registryToken = "$env:CDAF_REGISTRY_TOKEN"
    Write-Host "[$scriptName]   CDAF_REGISTRY_TOKEN : $(MASKED $registryToken) (loaded from environment variable)"
} else {
	$registryToken = & "${CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_REGISTRY_TOKEN"
	if ( $registryToken ) { $registryToken = Invoke-Expression "Write-Output $registryToken" }
	if ( $registryToken ) {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_TOKEN : $(MASKED $registryToken) (loaded from manifest.txt)"
	} else {	
	    Write-Host "[$scriptName]   CDAF_REGISTRY_TOKEN : (not supplied, login and push will not be attempted)"
	}
}

if ( $env:CDAF_REGISTRY_TAG ) {
	$registryTags = "$env:CDAF_REGISTRY_TAG"
    Write-Host "[$scriptName]   CDAF_REGISTRY_TAG   : $registryTags (loaded from environment variable, supports space separated lis)`n"
} else {
	$registryTags = & "${CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_REGISTRY_TAG"
	if ( $registryTags ) { $registryTags = Invoke-Expression "Write-Output $registryTags" }
	if ( $registryTags ) {
	    Write-Host "[$scriptName]   CDAF_REGISTRY_TAG   : $registryTags (loaded from manifest.txt, supports space separated lis)`n"
	} else {
		$registryTags = 'latest'
	    Write-Host "[$scriptName]   CDAF_REGISTRY_TAG   : (default, supports space separated list)`n"
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
		foreach ( $image in $constructor ) {
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

			executeExpression "cd ${transient}\${image}"

			# 2.6.1 Default Dockerfile for imageBuild
			if ( ! ( Test-Path '.\Dockerfile' )) {
				Write-Host "`n[$scriptName] .\Dockerfile not found, creating default`n"
			
				Set-Content '.\Dockerfile' '# DOCKER-VERSION 1.2.0'
				Add-Content '.\Dockerfile' 'ARG CONTAINER_IMAGE'
				Add-Content '.\Dockerfile' 'FROM ${CONTAINER_IMAGE}'
				Add-Content '.\Dockerfile' ''
				Add-Content '.\Dockerfile' 'WORKDIR /solution'
				
				$stringWithQuotes = 'SHELL ["powershell", "-Command", "$ErrorActionPreference = ' + "'Stop'" + '; $ProgressPreference = ' + "'Continue'" + '; $verbosePreference = ' + "'Continue'" + ';"]'
				Add-Content '.\Dockerfile' $stringWithQuotes
				Add-Content '.\Dockerfile' 'COPY ./ ./TasksLocal/'
				if ( Test-Path "delivery.ps1" ) {
					Add-Content '.\Dockerfile' 'RUN ./TasksLocal/delivery.ps1 IMMUTABLE'
				}
				Add-Content '.\Dockerfile' ''
				Add-Content '.\Dockerfile' 'WORKDIR /solution/workspace'
				Add-Content '.\Dockerfile' ''
				if ( Test-Path "keepAlive.ps1" ) {
					Add-Content '.\Dockerfile' 'CMD ["../keepAlive.ps1"]'
				}
			}

			Write-Host "--- Dockerfile ---`n"    
			Get-Content '.\Dockerfile'
			Write-Host "`n--- Dockerfile ---`n"    

			if ( $optionalArgs ) {
				if ( $baseImage ) {
					executeExpression "& '${CDAF_CORE}\dockerBuild.ps1' ${id}_${image} $BUILDNUMBER -optionalArgs '${optionalArgs}' -baseImage '$baseImage'"
				} else {
					executeExpression "& '${CDAF_CORE}\dockerBuild.ps1' ${id}_${image} $BUILDNUMBER -optionalArgs '${optionalArgs}'"
				}
			} else {
				if ( $baseImage ) {
					executeExpression "& '${CDAF_CORE}\dockerBuild.ps1' ${id}_${image} $BUILDNUMBER -baseImage '$baseImage'"
				} else {
					executeExpression "& '${CDAF_CORE}\dockerBuild.ps1' ${id}_${image} $BUILDNUMBER"
				}
			}
			executeExpression "cd '$workspace'"
		}

		$pushFeatureBranch = & "${CDAF_CORE}\getProperty.ps1" "${manifest}" "pushFeatureBranch"
		if ( $pushFeatureBranch -ne 'yes' ) {
			$REVISION = & "${CDAF_CORE}\getProperty.ps1" "${manifest}" "REVISION"
			$defaultBranch = & "${CDAF_CORE}\getProperty.ps1" "${manifest}" "defaultBranch"
			if (!( $defaultBranch )) {
				$defaultBranch = 'master'
			}
			if ( $REVISION -ne $defaultBranch ) {
				Write-Host "defaultBranch = $defaultBranch"
				Write-Host "Do not push feature branch ($REVISION), set pushFeatureBranch=yes to force push."
				$skipPush = 'yes'
			}
		}

		# 2.2.0 Integrated Registry push, not masking of secrets, it is expected the CI tool will know to mask these
		if ( $skipPush -eq 'yes' ) {
			if ( $registryToken ) {
				# Log the password, rely on the toolchain mask
				EXECMD "docker login --username $registryUser --password $registryToken $registryURL"
				foreach ( $tag in $registryTags.Split() ) {
					EXECMD "docker tag ${id}_${image}:$BUILDNUMBER $tag"
					EXECMD "docker push $tag"
				}
			} else {
				Write-Host "CDAF_REGISTRY_TOKEN not set, to push to registry set CDAF_REGISTRY_URL, CDAF_REGISTRY_TAG, CDAF_REGISTRY_USER & CDAF_REGISTRY_TOKEN"
				Write-Host "Do not set CDAF_REGISTRY_URL when pushing to dockerhub"
			}
		}
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0