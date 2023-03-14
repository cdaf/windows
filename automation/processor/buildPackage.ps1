Param (
	[string]$BUILDNUMBER,
	[string]$REVISION,
	[string]$ACTION,
	[string]$SOLUTION,
	[string]$AUTOMATIONROOT,
	[string]$LOCAL_WORK_DIR,
	[string]$REMOTE_WORK_DIR
)

Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Security

cmd /c "exit 0"
$error.clear()
$scriptName = 'buildPackage.ps1'

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
				Write-Host "[$scriptName][WARN] `$Error = $Error" ; $Error.clear()
				Write-Host "[$scriptName][WARN] $Error array populated but `$LASTEXITCODE = $LASTEXITCODE so continuing ...`n" -ForegroundColor Yellow
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_STANDARD_ERROR -eq 'yes' ) {
				Write-Host "[$scriptName][WARN] `$Error = $error"
				$Error.clear()
				Write-Host "[$scriptName][WARN] `$env:CDAF_IGNORE_STANDARD_ERROR is 'yes' so continuing ..." -ForegroundColor Yellow
	    	} else {
		    	Write-Host "[$scriptName][ERROR] `$Error = $error" ; $Error.clear()
				Write-Host "[$scriptName][ERROR] `$env:CDAF_IGNORE_STANDARD_ERROR is $env:CDAF_IGNORE_STANDARD_ERROR, exiting with error code 1113 ..."  -ForegroundColor Red ; exit 1113
	    	}
		}
	}
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeReturn ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

# Entry Point for Build Process, child scripts inherit the functions of parent scripts, so these definitions are global for the CI process
# Primary powershell, returns exitcode to DOS
function exitWithCode ($message, $exitCode) {
    write-host "[$scriptName] $message" -ForegroundColor Red
    write-host "[$scriptName]   Returning errorlevel $exitCode to DOS" -ForegroundColor Magenta
    $host.SetShouldExit($exitCode)
    exit $exitCode
}

function passExitCode ($message, $exitCode) {
    write-host "[$scriptName] $message" -ForegroundColor Red
    write-host "[$scriptName]   Exiting with `$LASTEXITCODE $exitCode" -ForegroundColor Magenta
    exit $exitCode
}

function exceptionExit ($exception) {
    write-host "[$scriptName]   Exception details follow ..." -ForegroundColor Red
    Write-Host $exception.Exception|format-list -force
    write-host "[$scriptName] Returning errorlevel (20) to DOS" -ForegroundColor Magenta
    $host.SetShouldExit(20)
    exit
}

# Not used in this script because called from DOS, but defined here for all child scripts
function taskFailure ($taskName) {
    write-host
    write-host "[$scriptName] Failure occured! Code returned ... $taskName" -ForegroundColor Red
    $host.SetShouldExit(30)
    exit 30
}

function taskWarning { 
    write-host "[$scriptName] Warning, $taskName encountered an error that was allowed to proceed." -ForegroundColor Yellow
}

function itemRemove ($itemPath) { 
	if ( Test-Path $itemPath ) {
		write-host "[$scriptName] Delete $itemPath"
		Remove-Item $itemPath -Recurse 
		if(!$?){ taskFailure "Remove-Item $itemPath" }
	}
}

function pathTest ($pathToTest) { 
	if ( Test-Path $pathToTest ) {
		Write-Host "found ($pathToTest)"
	} else {
		Write-Host "none ($pathToTest)"
	}
}

function getProp ($propName, $propertiesFile) {
	try {
		$propValue=$(& $AUTOMATIONROOT\remote\getProperty.ps1 $propertiesFile $propName)
		if(!$?){ taskWarning }
	} catch { exceptionExit $_ }
	
    return $propValue
}

function dockerStart {
	Write-Host "[$scriptName] Docker installed but not running, `$env:CDAF_DOCKER_REQUIRED is set so will try and start"
	executeExpression 'Start-Service Docker'
	Write-Host '$dockerStatus = ' -NoNewline 
	$dockerStatus = (Get-Service Docker).Status
	if ( $dockerStatus -ne 'Running' ) {
		Write-Host "[$scriptName] Unable to start Docker, `$dockerStatus = $dockerStatus"
		exit 8910
	}
}

# 2.4.1 Use the function call to separate fields, this allows support for whitespace and quote wrapped values
function cmProperties {
	if ( $args[0] ) {
		if ( $args[0] -ne 'context' ) { # Colum header
			if ( $args[0] -eq 'remote' ) {
				$cdafPath="./propertiesForRemoteTasks"
			} elseif ( $args[0] -eq 'local' ) {
				$cdafPath="./propertiesForLocalTasks"
			} elseif ( $args[0] -eq 'container' ) {
				$cdafPath="./propertiesForContainerTasks"
			} else {
				Write-Host "[$scriptName] Unknown CM context $($args[0]), supported contexts are rempote, local or container"
				exit 5922
			}
			if ( ! (Test-Path $cdafPath) ) {
				Write-Host "[$scriptName]   mkdir $(mkdir $cdafPath)"
			}
			Write-Host "[$scriptName]   Generating ${cdafPath}/$($args[1])"
			foreach ($field in $columns) {
				if ( $columns.IndexOf($field) -gt 1 ) { # do not create entries for context and target
					if ( $($args[$columns.IndexOf($field)]) ) { # Only write properties that are populated
						Add-Content "${cdafPath}/$($args[1])" "${field}=$($args[$columns.IndexOf($field)])"
					}
				}
			}
			if ( ! ( Test-Path ${cdafPath}/$($args[1]) )) {
				Write-Host "[$scriptName]   [WARN] Property file ${cdafPath}/$($args[1]) not created as containers definition contains no properties."
			}
		}
	}
}

# 2.4.1 Use the function call to separate fields, this allows support for whitespace and quote wrapped values
function pvProperties {
	for ($j=1; $j -le $args.Count; $j++) {
		if (( $script:pvContext[$j] ) -and ( $args[$j] )) {
			if ( $script:pvContext[$j] -eq 'remote' ) {
				$cdafPath="./propertiesForRemoteTasks"
			} elseif ( $script:pvContext[$j] -eq 'local' ) {
				$cdafPath="./propertiesForLocalTasks"
			} elseif ( $script:pvContext[$j] -eq 'container' )  {
				$cdafPath="./propertiesForContainerTasks"
			} else {
				Write-Host "[$scriptName] Unknown PV context $($script:pvContext[$j]), supported contexts are rempote, local or container"
				exit 5923
			}
			if ( ! (Test-Path $cdafPath) ) {
				Write-Host "[$scriptName]   mkdir $(mkdir $cdafPath)"
			}
			if ( ! ( Test-Path "${cdafPath}/$($script:pvtarget[$j])" )) {
				Write-Host "[$scriptName]   Generating ${cdafPath}/$($script:pvtarget[$j])"
			}
			Add-Content "${cdafPath}/$($script:pvtarget[$j])" "$($args[0])=$($args[$j])"
		}
	}
}

# Load automation root out of sequence as needed for solution root derivation
if (!($AUTOMATIONROOT)) {
	$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
	$AUTOMATIONROOT = split-path -parent $scriptPath
}

# Check for user defined solution folder, i.e. outside of automation root, if found override solution root
Write-Host "[$scriptName]   SOLUTIONROOT    : " -NoNewline
foreach ($item in (Get-ChildItem -Path ".")) {
	if (Test-Path $item -PathType "Container") {
		if (Test-Path "$item\CDAF.solution") {
			$SOLUTIONROOT=$item
		}
	}
}
if ($SOLUTIONROOT) {
	write-host "$SOLUTIONROOT (override $SOLUTIONROOT\CDAF.solution found)"
} else {
	exitWithCode "No directory found containing CDAF.solution, please create a single occurance of this file." 7612
}
$SOLUTIONROOT = (Get-Item $SOLUTIONROOT).FullName

if ( $BUILDNUMBER ) {
	Write-Host "[$scriptName]   BUILDNUMBER     : $BUILDNUMBER"
} else { 
	$counterFile = "$env:USERPROFILE\buildnumber.counter"
	# Use a simple text file ($counterFile) for incrimental build number, using the same logic as cdEmulate.ps1
	if ( Test-Path "$counterFile" ) {
		$buildNumber = Get-Content "$counterFile"
	} else {
		$buildNumber = 0
	}
	[int]$buildnumber = [convert]::ToInt32($buildNumber)
	if ( $action -ne "cdonly" ) { # Do not incriment when just deploying
		$buildNumber += 1
	}
	Set-Content "$counterFile" "$BUILDNUMBER"
    Write-Host "[$scriptName]   BUILDNUMBER     : $BUILDNUMBER (not supplied, generated from local counter file)"
}

if ($REVISION) {
	if ( $REVISION.contains('$')) {
		$REVISION = Invoke-Expression "Write-Output `"$REVISION`""
	}
    Write-Host "[$scriptName]   REVISION        : $REVISION"
} else {
	if ( $env:CDAF_BRANCH_NAME ) {
		$REVISION = $env:CDAF_BRANCH_NAME
	    Write-Host "[$scriptName]   REVISION        : $REVISION (not supplied, derived from `$env:CDAF_BRANCH_NAME)"
	} else {
		$versionTest = $(cmd /c git --version 2>&1)
		if ( $LASTEXITCODE -ne 0 ) {
			cmd /c "exit 0"
			$error.clear()
			$REVISION = 'revision'
			Write-Host "[$scriptName]   REVISION        : $REVISION (default, unable to determine from Git)"
		} else {
			$REVISION = $(git rev-parse --abbrev-ref HEAD 2>&1)
			if ( $LASTEXITCODE -eq 0 ) {
				Write-Host "[$scriptName]   REVISION        : $REVISION (determined from Git branch workspace)"
			} else {
				cmd /c "exit 0"
				$error.clear()
				$REVISION = 'revision'
				Write-Host "[$scriptName]   REVISION        : $REVISION (default, Git installed but not a Git workspace)"
			}
		}
	}
}
if ( $REVISION -match '/' ) {
	$branchBase = $REVISION.Split('/')[-1]
} else {
	$branchBase = $REVISION
}
$REVISION = ($branchBase -replace '[^a-zA-Z0-9]', '').ToLower()

Write-Host "[$scriptName]   ACTION          : $ACTION"

if ($SOLUTION) {
	Write-Host "[$scriptName]   SOLUTION        : $SOLUTION"
} else {
	$SOLUTION = getProp 'solutionName' "$SOLUTIONROOT\CDAF.solution"
	if ($SOLUTION) {
		Write-Host "[$scriptName]   SOLUTION        : $SOLUTION (from `$SOLUTIONROOT\CDAF.solution)"
	} else {
		exitWithCode "SOLUTION_NOT_FOUND Solution not supplied and unable to derive from $SOLUTIONROOT\CDAF.solution" 22
	}
}

# Arguments out of order, as automation root processed first
if ( $LOCAL_WORK_DIR ) {
	Write-Host "[$scriptName]   LOCAL_WORK_DIR  : $LOCAL_WORK_DIR"
} else {
	$LOCAL_WORK_DIR = 'TasksLocal'
	Write-Host "[$scriptName]   LOCAL_WORK_DIR  : $LOCAL_WORK_DIR (default)"
}

if ( $REMOTE_WORK_DIR ) {
	Write-Host "[$scriptName]   REMOTE_WORK_DIR : $REMOTE_WORK_DIR"
} else {
	$REMOTE_WORK_DIR = 'TasksRemote'
	Write-Host "[$scriptName]   REMOTE_WORK_DIR : $REMOTE_WORK_DIR (default)"
}

$prebuild = "$SOLUTIONROOT\prebuild.tsk"
Write-Host -NoNewLine "[$scriptName]   Pre-build Task  : " 
if (Test-Path "$prebuild") {
	Write-Host "found ($prebuild)"
} else {
	Write-Host "none ($prebuild)"
}

$postbuild = "$SOLUTIONROOT\postbuild.tsk"
Write-Host -NoNewLine "[$scriptName]   Post-build Task : " 
if (Test-Path "$postbuild") {
	Write-Host "found ($postbuild)"
} else {
	Write-Host "none ($postbuild)"
}

# Load automation root as environment variable
$env:CDAF_AUTOMATION_ROOT = $AUTOMATIONROOT
Write-Host "[$scriptName]   AUTOMATIONROOT  : $AUTOMATIONROOT" 

# Runtime information
Write-Host "[$scriptName]   pwd             : $(Get-Location)"
Write-Host "[$scriptName]   hostname        : $(hostname)" 
Write-Host "[$scriptName]   whoami          : $(whoami)"

$cdafVersion = getProp 'productVersion' "$AUTOMATIONROOT\CDAF.windows"
Write-Host "[$scriptName]   CDAF Version    : $cdafVersion"

# 2.5.5 default error diagnostic command as solution property
if ( $env:CDAF_ERROR_DIAG ) {
	Write-Host "[$scriptName]   CDAF_ERROR_DIAG : $CDAF_ERROR_DIAG"
} else {
	$env:CDAF_ERROR_DIAG = getProp 'CDAF_ERROR_DIAG' "$SOLUTIONROOT\CDAF.solution"
	if ( $env:CDAF_ERROR_DIAG ) {
		Write-Host "[$scriptName]   CDAF_ERROR_DIAG : $CDAF_ERROR_DIAG (defined in $SOLUTIONROOT\CDAF.solution)"
	} else {
		Write-Host "[$scriptName]   CDAF_ERROR_DIAG : (not set or defined in $SOLUTIONROOT\CDAF.solution)"
	}
}

# Process optional post-packaging tasks (Task driver support added in release 2.4.4)
if (Test-Path "$prebuild") {
	Write-Host "`n[$scriptName] Process Pre-Build Task ...`n"
	& $AUTOMATIONROOT\remote\execute.ps1 $SOLUTION $BUILDNUMBER "package" "$prebuild" $ACTION
	if(!$?){ exceptionExit ".$AUTOMATIONROOT\remote\execute.ps1 $SOLUTION $BUILDNUMBER `"package`" `"$prebuild`" $ACTION" }
}

$containerImage = getProp 'containerImage' "$SOLUTIONROOT\CDAF.solution"
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

# CDAF 1.6.7 Container Build process
if ( $ACTION -eq 'container_build' ) {
	Write-Host "`n[$scriptName] `$ACTION = $ACTION, container build detection skipped ...`n"
} else {

	# Process optional post-packaging tasks (Task driver support added in release 2.4.4)
	if (Test-Path "$postbuild") {
		Write-Host "`n[$scriptName] Process Post-Build Task ...`n"
		& $AUTOMATIONROOT\remote\execute.ps1 $SOLUTION $BUILDNUMBER "package" "$postbuild" $ACTION
		if(!$?){ exceptionExit ".$AUTOMATIONROOT\remote\execute.ps1 $SOLUTION $BUILDNUMBER `"package`" `"$postbuild`" $ACTION" }
	}

	# 2.5.5 support conditional containerBuild based on environment variable
	$containerBuildProp = getProp 'containerBuild' "$SOLUTIONROOT\CDAF.solution"
	if ( $containerBuildProp ) {
		$containerBuild = Invoke-Expression "Write-Output `"$containerBuildProp`""
		if ( $containerBuild ) {
			if (( $env:CDAF_SKIP_CONTAINER_BUILD ) -or ( $ACTION -eq 'skip_container_build' )) {
				Write-Host "`n[$scriptName] `$ACTION = $ACTION, container build defined (${containerBuild}) but skipped ...`n"
				Clear-Variable -Name 'containerBuild'
			} else {
				if ( $LASTEXITCODE -ne 0 ) {
					$error.clear()
					cmd /c "exit 0"
					Write-Host "[$scriptName]   containerBuild  : containerBuild defined in $SOLUTIONROOT\CDAF.solution, but Docker not installed, will attempt to execute natively"
					Clear-Variable -Name 'containerBuild'
					$executeNative = $true
				} else {
					Write-Host "[$scriptName]   containerBuild  : $containerBuild"
					$versionTest = cmd /c docker --version 2`>`&1
					if ( $LASTEXITCODE -ne 0 ) {
						$error.clear()
						cmd /c "exit 0"
						Write-Host "[$scriptName]   Docker          : (not installed, will attempt to execute natively)"
						Clear-Variable -Name 'containerBuild'
						$executeNative = $true
					} else {
						$array = $versionTest.split(" ")
						$dockerRun = $($array[2])
						Write-Host "[$scriptName]   Docker          : $dockerRun"

						# Test Docker is running
						If (Get-Service Docker -ErrorAction SilentlyContinue) {
							$dockerStatus = (Get-Service Docker).Status
							if ( $dockerStatus -ne 'Running' ) {
								if ( $dockerdProcess = Get-Process dockerd -ea SilentlyContinue ) {
									Write-Host "[$scriptName] Process dockerd is running..."
								} else {
									Write-Host "[$scriptName] Process dockerd is not running..."
								}
							}
							if (( $dockerStatus -ne 'Running' ) -and ( $null -eq $dockerdProcess )){
								if ( $env:CDAF_DOCKER_REQUIRED ) {
									dockerStart
								} else {			    
									Write-Host "[$scriptName] Docker installed but not running, will attempt to execute natively (set `$env:CDAF_DOCKER_REQUIRED if docker is mandatory)"
									cmd /c "exit 0"
									Clear-Variable -Name 'containerBuild'
									$executeNative = $true
								}
							}
						}

						Write-Host "[$scriptName] List all current images"
						Write-Host 'cmd /c docker images 2`>`&1'
						$imageTest = cmd /c docker images 2`>`&1
						if ( $LASTEXITCODE -ne 0 ) {
							cmd /c "exit 0"
							$error.clear()
							Write-Host "[$scriptName] Docker not responding, will attempt to execute natively (set `$env:CDAF_DOCKER_REQUIRED if docker is mandatory)"
							if ( $env:CDAF_DOCKER_REQUIRED ) {
								dockerStart
							} else {			    
								Write-Host "[$scriptName]   Docker installed but not running, will attempt to execute natively (set `$env:CDAF_DOCKER_REQUIRED if docker is mandatory)"
								cmd /c "exit 0"
								Clear-Variable -Name 'containerBuild'
								$executeNative = $true
							}
						} else {
							$imageTest
						}
					}
				}
			}
		} else {
			Write-Host "[$scriptName]   containerBuild  : set to '$containerBuildProp' but does not resolve, will perform native build"
		}
	} else {
		Write-Host "[$scriptName]   containerBuild  : (not defined in $SOLUTIONROOT\CDAF.solution)"
	}
}

# 2.2.0 Image Build as incorperated function
$imageBuild = getProp 'imageBuild' "$SOLUTIONROOT\CDAF.solution"
if ( $imageBuild ) {
	$versionTest = cmd /c docker --version 2`>`&1
	if ( $LASTEXITCODE -ne 0 ) {
		cmd /c "exit 0"
		$error.clear()
		$skipImageBuild = "imageBuild defined in $SOLUTIONROOT\CDAF.solution, but Docker not in use, imageBuild will not be attempted"
		Write-Host "[$scriptName]   imageBuild      : $skipImageBuild"
	} else {
		If (Get-Service Docker -ErrorAction SilentlyContinue) {
			$dockerStatus = (Get-Service Docker).Status
			if ( $dockerStatus -ne 'Running' ) {
				if ( $dockerdProcess = Get-Process dockerd -ea SilentlyContinue ) {
					Write-Host "[$scriptName] Process dockerd is running..."
				} else {
					Write-Host "[$scriptName] Process dockerd is not running..."
				}
			}
			if (( $dockerStatus -ne 'Running' ) -and ( $null -eq $dockerdProcess )){
				if ( $env:CDAF_DOCKER_REQUIRED ) {
					dockerStart
				} else {			    
					Write-Host "[$scriptName] Docker installed but not running, will attempt to execute natively (set `$env:CDAF_DOCKER_REQUIRED if docker is mandatory)"
					cmd /c "exit 0"
					Clear-Variable -Name 'containerBuild'
					$executeNative = $true
				}
			}
		}
	}

	if ( $executeNative ) { # docker test already performed
		Write-Host "[$scriptName]   imageBuild      : imageBuild defined in $SOLUTIONROOT\CDAF.solution, but Docker not in use, imageBuild will not be attempted"
	} else {
		Write-Host "[$scriptName]   imageBuild      : $imageBuild"
	}
} else {
	Write-Host "[$scriptName]   imageBuild      : (not defined in $SOLUTIONROOT\CDAF.solution)"
}

# added in release 1.7.8, extended to list in 1.8.11, moved from build to pre-process 1.8.14), added container tasks 2.4.0
Write-Host "`n[$scriptName] Properties generator"
$itemList = @("propertiesForLocalTasks", "propertiesForRemoteTasks", "propertiesForContainerTasks")
foreach ($itemName in $itemList) {  
	itemRemove ".\${itemName}"
}

$configManagementList = Get-ChildItem -Path "$SOLUTIONROOT" -Name '*.cm'
if ( $configManagementList ) {
	foreach ($item in $configManagementList) {
		Write-Host "[$scriptName]   CM Driver       : $item"
	}
} else {
		Write-Host "[$scriptName]   CM Driver       : none ($SOLUTIONROOT\*.cm)"
}

$pivotList = Get-ChildItem -Path "$SOLUTIONROOT" -Name '*.pv'
if ( $pivotList ) {
	foreach ($item in $pivotList) {
		Write-Host "[$scriptName]   PV Driver       : $item"
	}
} else {
		Write-Host "[$scriptName]   PV Driver       : none ($SOLUTIONROOT\*.pv)"
}

# Process table with properties as fields and environments as rows, 2.4.0 extend for propertiesForContainerTasks
foreach ($propertiesDriver in $configManagementList) {
	Write-Host "`n[$scriptName] Generating properties files from ${propertiesDriver}"
	$columns = ( -split (Get-Content $SOLUTIONROOT\$propertiesDriver -First 1 ))
	foreach ( $line in (Get-Content $SOLUTIONROOT\$propertiesDriver )) {
		$line = $line.Replace('$', '`$')
		Invoke-Expression "cmProperties $line"
	}
}

# 1.9.3 add pivoted CM table support, with properties as rows and environments as fields, 2.4.0 extend for propertiesForContainerTasks
foreach ($propertiesDriver in $pivotList) {
	Write-Host "`n[$scriptName] Generating properties files from ${propertiesDriver}"
	$pvRows = Get-Content $SOLUTIONROOT\$propertiesDriver
	$script:pvContext = -split $pvRows[0]
	$script:pvtarget = -split $pvRows[1]
    for ($i=2; $i -le $pvRows.Count; $i++) {
    	$line = $pvRows[$i]
    	if ( $line ) {
			$line = $line.Replace('$', '`$')
			Invoke-Expression "pvProperties $line"
		}
	}
}

if (( $containerBuild ) -and ( $ACTION -ne 'packageonly' )) {

	Write-Host "`n[$scriptName] Execute Container build, this performs cionly, buildonly is ignored.`n" -ForegroundColor Green
	executeExpression $containerBuild

} else { # Native build
	
	if ( $ACTION -eq 'packageonly' ) {
		if ( $containerBuild ) {
			Write-Host "`n[$scriptName] ACTION is $ACTION so do not use container build process" -ForegroundColor Yellow
		} else {
			Write-Host "`n[$scriptName] ACTION is $ACTION so skipping build process" -ForegroundColor Yellow
		}
	} else {
		Write-Host
		executeExpression "& $AUTOMATIONROOT\buildandpackage\buildProjects.ps1 $SOLUTION $BUILDNUMBER $REVISION $AUTOMATIONROOT $SOLUTIONROOT $ACTION"
	}
	
	if (( $ACTION -eq 'buildonly' ) -or ( $ACTION -eq 'clean' )) {
		Write-Host "`n[$scriptName] ACTION is $ACTION so skipping package process" -ForegroundColor Yellow
	} else {
		Write-Host
		executeExpression "& $AUTOMATIONROOT\buildandpackage\package.ps1 $SOLUTION $BUILDNUMBER $REVISION $AUTOMATIONROOT $SOLUTIONROOT $LOCAL_WORK_DIR $REMOTE_WORK_DIR $ACTION"
	}
}

if ( $ACTION -ne 'container_build' ) {

	# 2.2.0 Image Build as an incorperated function, no longer conditional on containerBuild, but do not attempt if within containerbuild
	if ( $imageBuild ) {

		Write-Host "[$scriptName] Execute image build..."
		if ( $skipImageBuild ) { # docker test already performed
			Write-Host "[$scriptName] $skipImageBuild"
		} else {
			$runtimeImage = getProp 'runtimeImage' "$SOLUTIONROOT\CDAF.solution"
			if ( $runtimeImage ) {
				Write-Host "[$scriptName]   runtimeImage  = $runtimeImage"
			} else {
				$runtimeImage = getProp 'containerImage' "$SOLUTIONROOT\CDAF.solution"
				if ( $runtimeImage ) {
					Write-Host "[$scriptName]   runtimeImage  = $runtimeImage (runtimeImage not found, using containerImage)"
				} else {
					if ( $Env:CONTAINER_IMAGE ) {
						Write-Host "[$scriptName][WARN] neither runtimeImage nor containerImage defined in $SOLUTIONROOT/CDAF.solution, assuming a hardcoded image will be used."
					} else {
						Write-Host "[$scriptName][WARN] neither runtimeImage nor containerImage defined in $SOLUTIONROOT/CDAF.solution, however Environment Variable CONTAINER_IMAGE set to $CONTAINER_IMAGE, overrides image passed to dockerBuild."
						$runtimeImage = $env:CONTAINER_IMAGE
					}
				}
			}

			$constructor = getProp 'constructor' "$SOLUTIONROOT\CDAF.solution"
			if ( $constructor ) {
				Write-Host "[$scriptName]   constructor   = $constructor"
			}

			$defaultBranch = getProp 'defaultBranch' "$SOLUTIONROOT\CDAF.solution"
			if ( $defaultBranch ) {
				Write-Host "[$scriptName]   defaultBranch = $defaultBranch"
			} else {
				$defaultBranch = 'master'
			}

			# 2.2.0 Integrated Function using environment variables
			if ( $REVISION -eq $defaultBranch ) {
				$value = & $AUTOMATIONROOT\remote\getProperty.ps1 "$SOLUTIONROOT/CDAF.solution" "CDAF_REGISTRY_URL"
				if ( $value ) {
					$env:CDAF_REGISTRY_URL = Invoke-Expression "Write-Output $value"
				}
				$value = & $AUTOMATIONROOT\remote\getProperty.ps1 "$SOLUTIONROOT/CDAF.solution" "CDAF_REGISTRY_TAG"
				if ( $value ) {
					$env:CDAF_REGISTRY_TAG = Invoke-Expression "Write-Output $value"
				}
				$value = & $AUTOMATIONROOT\remote\getProperty.ps1 "$SOLUTIONROOT/CDAF.solution" "CDAF_REGISTRY_USER"
				if ( $value ) {
					$env:CDAF_REGISTRY_USER = Invoke-Expression "Write-Output $value"
				}
				$value = & $AUTOMATIONROOT\remote\getProperty.ps1 "$SOLUTIONROOT/CDAF.solution" "CDAF_REGISTRY_TOKEN"
				if ( $value ) {
					$env:CDAF_REGISTRY_TOKEN = Invoke-Expression "Write-Output $value"
				}
			}
			executeExpression "$imageBuild"

			$postBuild = getProp 'postBuild' "$SOLUTIONROOT\CDAF.solution"  
			if ( $postBuild ) {
				executeExpression "$postBuild"
			}
		}
	}

	# CDAF 2.1.0 Self-extracting Script Artifact
	$artifactPrefix = getProp 'artifactPrefix' "$SOLUTIONROOT\CDAF.solution"
	if ( $artifactPrefix ) {
		if (( $ACTION -eq 'buildonly' ) -or ( $ACTION -eq 'clean' )) {
			Write-Host "`n[$scriptName] artifactPrefix set ($artifactPrefix), but ACTION is $ACTION so skipping package process" -ForegroundColor Yellow
		} else {
			$artifactID = "${SOLUTION}-${artifactPrefix}.${BUILDNUMBER}"
			Write-Host "[$scriptName] artifactPrefix = $artifactID, generate single file artefact ..."
			if ( Test-Path $artifactID ) {
				executeExpression "Remove-Item '$artifactID' -Recurse -Force"
			}
			Write-Host "[$scriptName]   Created $(mkdir "$artifactID")"
			if ( Test-Path .\TasksLocal ) { 
				executeExpression "Move-Item '.\TasksLocal' '.\$artifactID'"
			} else {
				Write-Host "[$scriptName] package output .\TasksLocal missing! ABORTING with LASTEXITCODE 2548."
				exit 2548
			}

			$legacyPackage = getProp 'legacyPackage' "$SOLUTIONROOT\CDAF.solution"
			if ( $legacyPackage ) {
				$compressedArtefact = "${artifactID}.zip"
				executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
				executeExpression "[System.IO.Compression.ZipFile]::CreateFromDirectory('$(Get-Location)\$artifactID', '$(Get-Location)\${compressedArtefact}', 'Optimal', `$false)"
		
				$NewFileToAdd = "${SOLUTION}-${BUILDNUMBER}.zip"
				if ( Test-Path $NewFileToAdd ) {
					Write-Host "[$scriptName]   Include remote package in ${compressedArtefact}"
					$zip = [System.IO.Compression.ZipFile]::Open("$(Get-Location)\${compressedArtefact}","Update")
					$FileName = [System.IO.Path]::GetFileName($NewFileToAdd)
					executeExpression "[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(`$zip, '$(Get-Location)\$NewFileToAdd' , '$FileName') | Out-Null"
					$Zip.Dispose()
				}
				$SourceFile = (get-item "${artifactID}.zip").FullName
			} else {
				$compressedArtefact = "${artifactID}.tar.gz"
				$NewFileToAdd = "${SOLUTION}-${BUILDNUMBER}.zip"
				if ( Test-Path $NewFileToAdd ) {
					executeExpression "Move-Item $NewFileToAdd $artifactID"
				}
				executeExpression "cd $artifactID"
				executeExpression "tar -czf ../${compressedArtefact} ."
				executeExpression "cd .."
				$SourceFile = (get-item "${compressedArtefact}").FullName
			}

			Write-Host "[$scriptName]   Create single script artefact release.ps1"
			$SourceFile = (get-item ${compressedArtefact}).FullName
			
			[IO.File]::WriteAllBytes("$pwd\release.ps1",[char[]][Convert]::ToBase64String([IO.File]::ReadAllBytes($SourceFile)))
	
			$scriptLines = @('Param (', '[string]$ENVIRONMENT,' ,'[string]$RELEASE,','[string]$OPT_ARG',')','Import-Module Microsoft.PowerShell.Utility','Import-Module Microsoft.PowerShell.Management','Import-Module Microsoft.PowerShell.Security')
			$scriptLines += "Write-Host 'Launching release.ps1 (${artifactPrefix}.${BUILDNUMBER}) ...'"
			$scriptLines += '$Base64 = "'
			$scriptLines + (get-content "release.ps1") | set-content "release.ps1"
	
			Add-Content "release.ps1" '"'
			Add-Content "release.ps1" 'if ( Test-Path "TasksLocal" ) { Remove-Item -Recurse TasksLocal }'
			Add-Content "release.ps1" "Remove-Item ${SOLUTION}*.zip" # remote package
			Add-Content "release.ps1" '$Content = [System.Convert]::FromBase64String($Base64)'
			Add-Content "release.ps1" "Set-Content -Path '${compressedArtefact}' -Value `$Content -Encoding Byte"

			if ( $legacyPackage ) {
				# TODO conditional for PS core in the future Add-Content "release.ps1" "Set-Content -Path '${compressedArtefact}' -Value `$Content -AsByteStream"
				Add-Content "release.ps1" 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
				Add-Content "release.ps1" "[System.IO.Compression.ZipFile]::ExtractToDirectory(`"`$PWD\${compressedArtefact}`", `"`$PWD`")"
			} else {
				Add-Content "release.ps1" "tar -zxf ${compressedArtefact}"
			}

			Add-Content "release.ps1" '.\TasksLocal\delivery.bat "$ENVIRONMENT" "$RELEASE" "$OPT_ARG"'
			Add-Content "release.ps1" 'exit $LASTEXITCODE'
			$artefactList = @('release.ps1')
		}
	} else {
		$artefactList = @(Get-ChildItem *.zip)
		$artefactList += "$(Get-Location)\TasksLocal\"
	}
} else { # self-extracting release is never created in container_build
	$artefactList += "$(Get-Location)\TasksLocal\"
}

if ( $ACTION -like 'staging@*' ) { # Primarily for ADO pipelines
	$parts = $ACTION.split('@')
	$stageTarget = $parts[1]
	if ( Test-Path $stageTarget ) {
		executeExpression "Remove-Item -Recurse -Force $stageTarget\*"
	} else {
		Write-Host "Created $(mkdir $stageTarget)"
	}
	foreach ($artefactItem in $artefactList) {
		executeExpression "Copy-Item -Recurse '$artefactItem' '$stageTarget'"
	}
} else {
	$stageTarget = Get-Location
}

if ( $ACTION -ne 'container_build' ) {
	Write-Host "`n[$scriptName] Clean Workspace..."
	itemRemove "propertiesForLocalTasks"
	itemRemove "propertiesForRemoteTasks"
	itemRemove "propertiesForContainerTasks"
	itemRemove "manifest.txt"
	itemRemove "storeForLocal_manifest.txt"
	itemRemove "storeForRemote_manifest.txt"
	itemRemove "storeFor_manifest.txt"
	itemRemove "$REMOTE_WORK_DIR"
	if ( $artifactPrefix ) {
		itemRemove "$LOCAL_WORK_DIR"
		itemRemove "${SOLUTION}-${BUILDNUMBER}.zip"
		itemRemove "${compressedArtefact}"
		itemRemove "${artifactID}"
	}
}

if (( $ACTION -eq 'buildonly' ) -or ( $ACTION -eq 'clean' )) {
	Write-Host "`n[$scriptName][$(Get-Date)] $ACTION complete." -ForegroundColor Green
} else {
	Write-Host "`n[$scriptName][$(Get-Date)] Process complete, artefacts [$artefactList] placed in $stageTarget" -ForegroundColor Green
}
$error.clear()
exit 0