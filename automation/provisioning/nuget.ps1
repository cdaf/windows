Param (
  [string]$packageName,
  [string]$targetDirectory,
  [string]$subDirectory,
  [string]$version
)
$scriptName = 'nuget.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

# NuGet install is developer oriented for including packages into Visual Studio ecosystem, this script provides a wrapper for downloading a package and copying it to a destination, if the destination does not exist, it will be created.
Write-Host "`n[$scriptName] ---------- start ----------"
if ($packageName) {
    Write-Host "[$scriptName] packageName     : $packageName"
} else {
    Write-Host "[$scriptName] packageName not supplied, exiting with LASTEXITCODE 101" exit 101
}

if ($targetDirectory) {
    Write-Host "[$scriptName] targetDirectory : $targetDirectory"
} else {
    Write-Host "[$scriptName] targetDirectory not supplied, exiting with LASTEXITCODE 102" exit 102
}

if ($version) {
    Write-Host "[$scriptName] version         : $version"
    $optArg += " -version $version"
} else {
    Write-Host "[$scriptName] version         : ( not supplied )"
}

if ($subDirectory) {
    Write-Host "[$scriptName] subDirectory    : $subDirectory"
    $optArg += " -subDirectory $subDirectory"
} else {
    Write-Host "[$scriptName] subDirectory    : ( not supplied )"
}

$nugetOutDir = "$env:temp\packages"
if ( Test-Path $nugetOutDir ) {
	Write-Host "[$scriptName] $nugetOutDir exists, this is the cache NuGet will use"
} else {
	$newDir = executeExpression "New-Item -ItemType Directory -Force -Path `'$nugetOutDir`'"
	Write-Host "Created $($newDir.FullName)"
}

if ( Test-Path $targetDirectory ) {
	Write-Host "[$scriptName] $targetDirectory exists, if files exist they will be replaced"
} else {
	$newDir = executeExpression "New-Item -ItemType Directory -Force -Path `'$targetDirectory`'"
	Write-Host "Created $($newDir.FullName)"
}

if ($version) {
	executeExpression "nuget install $packageName -Version $version -OutputDirectory $nugetOutDir"
} else {
	executeExpression "nuget install $packageName -OutputDirectory $nugetOutDir"
}

$files = Get-ChildItem "$nugetOutDir\$packageName*"
if ($files) {
	Write-Host;	Write-Host "[$scriptName] Packages available ..."
	foreach ($file in $files) {
		Write-Host "[$scriptName]   $($file.name)"
		$packageDirectory = $($file.fullname)
	}
	Write-Host; Write-Host "[$scriptName] Using latest package ($packageDirectory)"
} else {
	Write-Host "[$scriptName] packageDirectory with prefix `'$packageName`' not found, exiting with error code 1"; exit 1
}

executeExpression "Copy-Item -Recurse -Force `"$packageDirectory\$subDirectory\**`" `"$targetDirectory`""

Write-Host "`n[$scriptName] ---------- stop ----------`n"
