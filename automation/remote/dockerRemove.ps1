Param (
  [string]$imageName,
  [string]$environment
)

cmd /c "exit 0"
$scriptName = 'dockerRemove.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeSuppress ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception|format-list -force; exit 2 }
	$error.clear()
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] Suppress `$LASTEXITCODE ($LASTEXITCODE)"; cmd /c "exit 0" } # reset LASTEXITCODE
}

Write-Host "`n[$scriptName] This script stops and removes all instances for the imageName, based "
Write-Host "[$scriptName] on environment tag. Use this to purge all targets for the environment."
Write-Host "`n[$scriptName] --- start ---"
if ($imageName) {
    Write-Host "[$scriptName] imageName   : $imageName"
} else {
    Write-Host "[$scriptName] imageName not supplied, exit with `$LASTEXITCODE = 1"; exit 1
}

if ($environment) {
    Write-Host "[$scriptName] environment : $environment (not passed, remove all)"
} else {
    Write-Host "[$scriptName] environment : $environment"
}

echo "[$scriptName] List all (running and stopped) containers (before)"
executeExpression "docker ps --all"

Write-Host "`n[$scriptName] As of 1.13.0 new prune commands, if using older version, suppress error"
executeSuppress "docker system prune -f"

Write-Host "`n[$scriptName] List stopped containers"
executeExpression "docker ps --filter `"status=exited`" -a"

$stoppedIDs = docker ps --filter "status=exited" -aq
if ($stoppedIDs) {
	Write-Host "`n[$scriptName] Remove stopped containers"
	executeSuppress "docker rm $stoppedIDs"
}

Write-Host "`n[$scriptName] Remove untagged orphaned (dangling) images"
foreach ($imageID in docker images -aq -f dangling=true) {
	executeSuppress "docker rmi -f $imageID"
}

if ($environment) {
	Write-Host "`n[$scriptName] Stop and remove containers based on label (cdaf.${imageName}.container.environment=${environment})"
	foreach ($container in docker ps --all --filter "label=cdaf.${imageName}.container.environment=${environment}" -q) {
		executeExpression "docker stop $container"
		executeExpression "docker rm $container"
	}
} else {
	Write-Host "`n[$scriptName] Stop and remove containers based on label (cdaf.${imageName}.container.environment)"
	foreach ($container in docker ps --all --filter "label=cdaf.${imageName}.container.environment" -q) {
		executeExpression "docker stop $container"
		executeExpression "docker rm $container"
	}
}

Write-Host "`n[$scriptName] List all (running and stopped) containers (after)"
executeExpression "docker ps --all"

Write-Host "`n[$scriptName] --- end ---"
$error.clear()
exit 0
