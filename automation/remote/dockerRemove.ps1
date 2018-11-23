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

if ($tag) {
    Write-Host "[$scriptName] tag         : $tag"
} else {
	$tag = 'latest'
    Write-Host "[$scriptName] tag         : $tag (default)"
}

if ($environment) {
    Write-Host "[$scriptName] environment : $environment (not passed, set to same value as tag)"
} else {
	$environment = $tag
    Write-Host "[$scriptName] environment : $environment"
}

echo "[$scriptName] List running containers (before)"
executeExpression "docker ps"

echo "[$scriptName] If tag is passed, attempt to stopo and remove single container based on tag, ignore if it does not exist"
if ($tag) {
	executeSuppress "docker ps"
	executeSuppress "docker ps"
}

Write-Host "`n[$scriptName] Stop and remove containers based on label (cdaf.${imageName}.container.environment=${environment})"
foreach ($container in docker ps --all --filter "label=cdaf.${imageName}.container.environment=${environment}" -q) {
	executeExpression "docker stop $container"
	executeExpression "docker rm $container"
}

Write-Host "`n[$scriptName] List running containers (after)"
executeExpression "docker ps"

Write-Host "`n[$scriptName] --- end ---"
$error.clear()
exit 0
