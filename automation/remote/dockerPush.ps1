Param (
	[string]$imageTag,
	[string]$registryContext,
	[string]$registryTags,
	[string]$registryToken,
	[string]$registryUser,
	[string]$registryURL
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

# 2.5.2 Return SHA256 as uppercase Hexadecimal, default algorith is SHA256, but setting explicitely should this change in the future
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

$scriptName = 'dockerPush.ps1'
cmd /c "exit 0"
$error.clear()

Write-Host "`n[$scriptName] ---------- start ----------"

# 2.6.0 Push Private Registry
$manifest = "${env:WORKSPACE}\manifest.txt"
if ( ! ( Test-Path ${manifest} )) {
	$manifest = "${SOLUTIONROOT}\CDAF.solution"
	if ( ! ( Test-Path ${manifest} )) {
		Write-Host "[$scriptName] Properties not found in ${env:WORKSPACE}\manifest.txt or ${manifest}!"
		exit 5343
	}
}

if ( $imageTag ) {
	Write-Host "[$scriptName]   imageTag        : $imageTag"
} else {
}

if ( $registryContext ) {
	Write-Host "[$scriptName]   registryContext : $registryContext"
} else {
	Write-Host "[$scriptName]   registryContext not supplied!"
	exit 2502
}

# 2.6.0 CDAF Solution property support, with environment variable override.
if ( $registryTags ) {
	Write-Host "[$scriptName]   registryTags    : $registryTags (can be space separated list)"
} else {
	if ( $env:CDAF_PUSH_REGISTRY_TAG ) {
		$imageTag = "$env:CDAF_PUSH_REGISTRY_TAG"
	    Write-Host "[$scriptName]   registryTags        : $registryTags (loaded from environment variable CDAF_PUSH_REGISTRY_TAG, supports space separated lis)`n"
	} else {
		$registryTags = & "${CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_PUSH_REGISTRY_TAG"
		if ( $registryTags ) { $registryTags = Invoke-Expression "Write-Output $registryTags" }
		if ( $registryTags ) {
			Write-Host "[$scriptName]   registryTags        : $registryTags"
		    Write-Host "[$scriptName]   registryTags        : $registryTags (loaded from manifest.txt, supports space separated lis)`n"
		} else {	
			$registryTags = 'latest'
			Write-Host "[$scriptName]   registryTags        : $registryTags (default, supports space separated list)"
		}
	}
}

if ( $registryToken ) {
	Write-Host "[$scriptName]   registryToken   : $(MASKED $registryToken) (MASKED)"
} else {
	if ( $env:CDAF_PUSH_REGISTRY_TOKEN ) {
		$registryToken = "$env:CDAF_PUSH_REGISTRY_TOKEN"
	    Write-Host "[$scriptName]   registryToken   : $(MASKED $registryToken) (loaded from environment variable)"
	} else {
		$registryToken = & "${CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_PUSH_REGISTRY_TOKEN"
		if ( $registryToken ) { $registryToken = Invoke-Expression "Write-Output $registryToken" }
		if ( $registryToken ) {
		    Write-Host "[$scriptName]   registryToken   : $(MASKED $registryToken) (loaded from manifest.txt)"
		} else {	
		    Write-Host "[$scriptName]   registryToken   : (not supplied, login and push will not be attempted)"
		}
	}
}

if ( $registryUser ) {
	Write-Host "[$scriptName]   registryUser    : $registryUser"
} else {
	if ( $env:CDAF_PUSH_REGISTRY_USER ) {
		$registryUser = "$env:CDAF_PUSH_REGISTRY_USER"
	    Write-Host "[$scriptName]   registryUser    : $registryUser (loaded from environment variable)"
	} else {
		$registryUser = & "${CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_PUSH_REGISTRY_USER"
		if ( $registryUser ) { $registryUser = Invoke-Expression "Write-Output $registryUser" }
		if ( $registryUser ) {
		    Write-Host "[$scriptName]   registryUser    : $registryUser (loaded from manifest.txt)"
		} else {	
			$registryUser = '.'
		    Write-Host "[$scriptName]   registryUser    : $registryUser (not supplied, set to default)"
		}
	}
}

if ( $registryURL ) {
	Write-Host  "[$scriptName]   registryURL     : $registryURL"
} else {
	if ( $env:CDAF_PUSH_REGISTRY_URL ) {
		$registryURL = $env:CDAF_PUSH_REGISTRY_URL
	    Write-Host "[$scriptName]   registryURL     : $registryURL (loaded from environment variable)"
	} else {	
		$registryURL = & "${CDAF_CORE}\getProperty.ps1" "${manifest}" "CDAF_PUSH_REGISTRY_URL"
		if ( $registryURL ) { $registryURL = Invoke-Expression "Write-Output $registryURL" }
		if ( $registryURL ) {
		    Write-Host "[$scriptName]   registryURL     : $registryURL (loaded from manifest.txt)"
		} else {
		    Write-Host "[$scriptName]   registryURL     : (not supplied, do not set when pushing to Dockerhub)"
		}
	}
}

if ( $registryToken ) {
	# Log the password, rely on the toolchain mask
	EXECMD "docker login --username $registryUser --password $registryToken $registryURL"
	if ( $registryURL ) {
		$registryContext = $registryURL + '/' + $registryContext
	}

	foreach ( $tag in $registryTags.Split() ) {
		EXECMD "docker tag ${imageTag} ${registryContext}:$tag"
		EXECMD "docker push ${registryContext}:$tag"
	}
} else {
	ERRMSG "registryToken not supplied, so push not attempted."
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0