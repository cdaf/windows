Param (
	[string]$id,
	[string]$BUILDNUMBER,
	[string]$containerImage
)

$scriptName = 'imageBuild.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception | format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
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

cmd /c "exit 0"
Write-Host "`n[$scriptName] ---------- start ----------`n"
if ( $id ) { 
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
}

Write-Host "[$scriptName]   pwd             : $(pwd)"
Write-Host "[$scriptName]   hostname        : $(hostname)"
Write-Host "[$scriptName]   whoami          : $(whoami)"
$workspace = $(pwd)
Write-Host "[$scriptName]   workspace       : $workspace"

$persist = "$env:TEMP\buildImage\${id}"
Write-Host "[$scriptName]   persist         : $persist"

Write-Host "Create the image file system locally if it does not exist`n"
if ( Test-Path "${persist}" ) {
	if (Test-Path "${persist}" -PathType "Leaf") {
		Write-Host "${persist} already exists, but is not a directory, replacing as directory"
		executeExpression "rm ${persist} -Force -Confirm:`$false"
		executeExpression "Write-Host 'Created $(mkdir ${persist})'"
	}
} else {
	executeExpression "Write-Host 'Created $(mkdir ${persist})'"
}

foreach ($server in (Get-ChildItem -Path "." -directory)) {
	Write-Host "`n----------------------"
	Write-Host "    ${server} server"    
	Write-Host "----------------------`n"
	if ( Test-Path "${persist}\${server}" ) {
		executeExpression "rm -Recurse ${persist}\${server}"
	}
	executeExpression "cp -Recurse .\${server} ${persist}"
	executeExpression "cp ../dockerBuild.ps1 ${persist}\${server}"
	executeExpression "cp -Recurse ../automation ${persist}\${server}"
	executeExpression "cd ${persist}\${server}"
	executeExpression "cat Dockerfile"
	executeExpression "./dockerBuild.ps1 ${id}_${server} $BUILDNUMBER"
	executeExpression "cd $workspace"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0