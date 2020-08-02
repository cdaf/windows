Param (
  [string]$packageName,
  [string]$targetDirectory,
  [string]$subDirectory,
  [string]$version
)
$scriptName = 'nuget.ps1'
$error.clear()
cmd /c "exit 0"

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1112 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red ; $error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE, $error[] = $error`n" -ForegroundColor Yellow
				$error.clear()
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName][WARN] $Error array populated but LASTEXITCODE not set, $error[] = $error`n" -ForegroundColor Yellow
			$error.clear()
		}
	}
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

$versionTest = cmd /c NuGet 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	cmd /c "exit 0"
	executeExpression "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls11,Tls12'"
	executeExpression "(New-Object System.Net.WebClient).DownloadFile('https://dist.nuget.org/win-x86-commandline/latest/nuget.exe', '$PWD\nuget.exe')"
	$versionTest = cmd /c NuGet 2`>`&1
	$array = $versionTest.split(" ")
	Write-Host "`n[$scriptName] NuGet version $($array[2]) (downloaded into $(Get-Item NuGet.exe))`n"
	$nugetCommand = './nuget.exe'
} else {
	$array = $versionTest.split(" ")
	Write-Host "`n[$scriptName] NuGet version $($array[2])`n"
	$nugetCommand = 'nuget'
}

if ($version) {
	executeExpression "$nugetCommand install $packageName -Version $version -OutputDirectory '$nugetOutDir'"
} else {
	executeExpression "$nugetCommand install $packageName -OutputDirectory '$nugetOutDir'"
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
