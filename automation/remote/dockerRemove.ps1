Param (
  [string]$imageName,
  [string]$environment
)
# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if ( $lastExitCode -ne 0 ) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode "; exit $lastExitCode }
}

$scriptName = 'dockerRemove.ps1'
Write-Host "`n[$scriptName] This script stops and removes all instances for the imageName, based "
Write-Host "[$scriptName] on environment tag. Use this to purge all targets for the environment."
Write-Host "`n[$scriptName] --- start ---"
if ($imageName) {
    Write-Host "[$scriptName] imageName     : $imageName"
} else {
    Write-Host "[$scriptName] imageName not supplied, exit with `$LASTEXITCODE = 1"; exit 1
}

if ($environment) {
    Write-Host "[$scriptName] environment : $environment"
} else {
	$environment = 'latest'
    Write-Host "[$scriptName] environment : $environment (default)"
}

echo "[$scriptName] List running containers (before)"
executeExpression "docker ps"

Write-Host "`n[$scriptName] Stop and remove containers based on label (cdaf.${imageName}.container.environment=${environment})"
foreach ($container in docker ps --all --filter "label=cdaf.${imageName}.container.environment=${environment}" -q) {
	executeExpression "docker stop $container"
	executeExpression "docker rm $container"
}

Write-Host "`n[$scriptName] List running containers (after)"
executeExpression "docker ps"

Write-Host "`n[$scriptName] --- end ---"
