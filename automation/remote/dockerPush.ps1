Param (
	[string]$imageTag,
	[string]$registryContext,
	[string]$registryTags,
	[string]$registryURL,
	[string]$registryUser,
	[string]$registryToken
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

# 2.5.2 Return SHA256 as uppercase Hexadecimal, default algorith is SHA256, but setting explicitely should this change in the future
function MASKED ($value) {
	(Get-FileHash -InputStream $([IO.MemoryStream]::new([byte[]][char[]]$value)) -Algorithm SHA256).Hash
}

$scriptName = 'dockerPush.ps1'
cmd /c "exit 0"
$error.clear()

Write-Host "`n[$scriptName] ---------- start ----------"
if ( $imageTag ) {
	Write-Host "[$scriptName]   imageTag        : $imageTag"
} else {
	Write-Host "[$scriptName]   imageTag not supplied!"
	exit 2501
}

if ( $registryContext ) {
	Write-Host "[$scriptName]   registryContext : $registryContext"
} else {
	Write-Host "[$scriptName]   registryContext not supplied!"
	exit 2502
}

if ( $registryTags ) {
	Write-Host "[$scriptName]   registryTags    : $registryTags (can be space separated list)"
} else {
	Write-Host "[$scriptName]   registryTags not supplied!"
	exit 2503
}

if ( $registryURL ) {
	if ( $registryURL -eq 'DOCKER-HUB' ) {
		Write-Host  "[$scriptName]   registryURL     : $registryURL (will be set to blank)"
		$registryURL = ''
	} else {
		Write-Host  "[$scriptName]   registryURL     : $registryURL"
	}
} else {
	Write-Host  "[$scriptName]   registryURL     : (not supplied, do not set when pushing to Dockerhub, can also set to DOCKER-HUB to ignore)"
}

if ( $registryUser ) {
	Write-Host "[$scriptName]   registryUser    : $registryUser"
} else {
	Write-Host "[$scriptName]   registryUser    : (not supplied, login will not be attempted)"
}

if ( $registryToken ) {
	Write-Host "[$scriptName]   registryToken   : $(MASKED $registryToken) (MASKED)"
} else {
	Write-Host "[$scriptName]   registryToken   : (not supplied, login will not be attempted)"
}

# DockerHub example
#   echo xxxxxx | docker login --username cdaf --password-stdin
#   docker tag iis_master:666 cdaf/iis:666
#   docker push cdaf/iis:666

# Private Registry example
#   echo xxxxxx | docker login --username cdaf --password-stdin https://private.registry
#   docker tag iis_master:666 https://private.registry/iis:666
#   docker push https://private.registry/iis:666

if (( $registryUser ) -and ( $registryToken )) {
	executeExpression "echo `$registryToken | docker login --username $registryUser --password-stdin $registryURL"
}

if ( $registryURL ) {
	$registryContext = $registryURL + '/' + $registryContext
}

foreach ( $tag in $registryTags.Split() ) {
	executeExpression "docker tag ${imageTag} ${registryContext}:$tag"
	executeExpression "docker push ${registryContext}:$tag"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0