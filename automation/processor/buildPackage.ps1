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

# Consolidated Error processing function
#  required : error message
#  optional : exit code, if not supplied only error message is written
function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Red
	} else {
		Write-Warning "`n[$scriptName]$message"
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
	if ( $exitcode ) {
		if ( $env:CDAF_ERROR_DIAG ) {
			Write-Host "`n[$scriptName] Invoke custom diag `$env:CDAF_ERROR_DIAG = $env:CDAF_ERROR_DIAG`n"
			Invoke-Expression $env:CDAF_ERROR_DIAG
		}
		Write-Host "`n[$scriptName] Exit with LASTEXITCODE = $exitcode`n" -ForegroundColor Red
		exit $exitcode
	}
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { ERRMSG "[TRAP] `$? = $?" 1211 }
	} catch {
		$message = $_.Exception.Message
		$_.Exception | format-list -force
		$_.Exception.StackTrace
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
			ERRMSG "[EXEC][EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[EXEC][EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			ERRMSG "[EXEC][EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
		} else {
			if ( $error ) {
				ERRMSG "[EXEC][WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[EXEC][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				ERRMSG "[EXEC][WARN] `$LASTEXITCODE not set, but standard error populated"
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
				ERRMGS " Unknown CM context $($args[0]), supported contexts are rempote, local or container" 5922
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
				ERRMSG "[PVERR] Unknown PV context $($script:pvContext[$j]), supported contexts are rempote, local or container" 5923
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

if ( ! $env:CDAF_COMMAND_SHELL ) {
	write-host "`n[$scriptName] ============================================"
	write-host "[$scriptName] Continuous Integration (CI) Process Starting"
	write-host "[$scriptName] ============================================"
}

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

	$origRev = $REVISION
	if ( $REVISION -match '/' ) {
		$REVISION = $REVISION.Split('/')[-1]
	}
	$REVISION = ($REVISION -replace '[^a-zA-Z0-9]', '').ToLower()
	if ( $origRev -ne $REVISION ) {
	    Write-Host "[$scriptName]   REVISION        : $REVISION (cleansed from $origRev)"
	} else {
	    Write-Host "[$scriptName]   REVISION        : $REVISION"
	}
} else {
	if ( $env:CDAF_BRANCH_NAME ) {
		$REVISION = $env:CDAF_BRANCH_NAME
	    Write-Host "[$scriptName]   REVISION        : $REVISION (not supplied, derived from `$env:CDAF_BRANCH_NAME)"
	} else {
		$REVISION = 'revision'
	}
}

Write-Host "[$scriptName]   ACTION          : $ACTION"

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

Write-Host "[$scriptName]   AUTOMATIONROOT  : " -NoNewline
if ( $AUTOMATIONROOT ) {
	write-host "$AUTOMATIONROOT"
} else {
	$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
	$AUTOMATIONROOT = split-path -parent $scriptPath
	Write-Host "$AUTOMATIONROOT (not supplied, derived from invocation)"
	$CDAF_CORE = "${AUTOMATIONROOT}\remote"
}
# Check for user defined solution folder, i.e. outside of automation root, if found override solution root
Write-Host "[$scriptName]   SOLUTIONROOT    : " -NoNewline
if ( $SOLUTIONROOT ) {
	write-host "$SOLUTIONROOT"
} else {
	foreach ($item in (Get-ChildItem -Path ".")) {
		if (Test-Path $item -PathType "Container") {
			if (Test-Path "$item\CDAF.solution") {
				$SOLUTIONROOT = $item
			}
		}
	}
	if ( $SOLUTIONROOT ) {
		$SOLUTIONROOT = (Get-Item $SOLUTIONROOT).FullName
		write-host "$SOLUTIONROOT (CDAF.solution found)"
	} else {
		exitWithCode "No directory found containing CDAF.solution, please create a single occurance of this file." 7612
	}
}
if ($SOLUTION) {
	Write-Host "[$scriptName]   SOLUTION        : $SOLUTION"
} else {
	$SOLUTION = getProp 'solutionName' "$SOLUTIONROOT\CDAF.solution"
	if ($SOLUTION) {
		Write-Host "[$scriptName]   SOLUTION        : $SOLUTION (found `$SOLUTIONROOT\CDAF.solution)"
	} else {
		exitWithCode "SOLUTION_NOT_FOUND Solution not supplied and unable to derive from $SOLUTIONROOT\CDAF.solution" 22
	}
}

# Runtime information
$env:WORKSPACE = (Get-Location).Path
Write-Host "[$scriptName]   pwd             : $env:WORKSPACE"
Write-Host "[$scriptName]   hostname        : $(hostname)" 
Write-Host "[$scriptName]   whoami          : $(whoami)"

$cdafVersion = getProp 'productVersion' "$AUTOMATIONROOT\CDAF.windows"
Write-Host "[$scriptName]   CDAF Version    : $cdafVersion"

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

#---------------------------------------------------------------------
# Configuration Management transformation only if not within container
#---------------------------------------------------------------------
if ( $ACTION -ne 'container_build' ) {

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

	# added in release 1.7.8, extended to list in 1.8.11, moved from build to pre-process 1.8.14), added container tasks 2.4.0
	Write-Host "`n[$scriptName] Remove Build Process Temporary files and directories"
	$itemList = @("manifest.txt", "propertiesForLocalTasks", "propertiesForRemoteTasks", "propertiesForContainerTasks")
	foreach ($itemName in $itemList) {  
		itemRemove ".\${itemName}"
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
}

#--------------------------------------------------------------------------
# 2.6.2 Only log system variables if set
#--------------------------------------------------------------------------
$loggingList = @()

# 2.5.5 default error diagnostic command as solution property
if ( $env:CDAF_ERROR_DIAG ) {
	$loggingList += "[$scriptName]   CDAF_ERROR_DIAG     : $CDAF_ERROR_DIAG"
} else {
	$env:CDAF_ERROR_DIAG = getProp 'CDAF_ERROR_DIAG' "$SOLUTIONROOT\CDAF.solution"
	if ( $env:CDAF_ERROR_DIAG ) {
		$loggingList += "[$scriptName]   CDAF_ERROR_DIAG     : $CDAF_ERROR_DIAG (defined in $SOLUTIONROOT\CDAF.solution)"
	}
}

if ( $env:CDAF_IGNORE_WARNING ) {
	$loggingList += "[$scriptName]   CDAF_IGNORE_WARNING : $CDAF_IGNORE_WARNING"
} else {
	$env:CDAF_IGNORE_WARNING = getProp 'CDAF_IGNORE_WARNING' "$SOLUTIONROOT\CDAF.solution"
	if ( $env:CDAF_IGNORE_WARNING ) {
		$loggingList += "[$scriptName]   CDAF_IGNORE_WARNING : $CDAF_IGNORE_WARNING (defined in $SOLUTIONROOT\CDAF.solution)"
	}
}

if ( $env:CDAF_OVERRIDE_TOKEN ) {
	$loggingList += "[$scriptName]   CDAF_OVERRIDE_TOKEN : $CDAF_OVERRIDE_TOKEN"
} else {
	$env:CDAF_OVERRIDE_TOKEN = getProp 'CDAF_OVERRIDE_TOKEN' "$SOLUTIONROOT\CDAF.solution"
	if ( $env:CDAF_OVERRIDE_TOKEN ) {
		$loggingList += "[$scriptName]   CDAF_OVERRIDE_TOKEN : $CDAF_OVERRIDE_TOKEN (defined in $SOLUTIONROOT\CDAF.solution)"
	}
}

if ( $loggingList ) {
	Write-Host "`n[$scriptName] CDAF System Variables Set ..."
	Write-Output $loggingList
}

#--------------------------------------------------------------------------
# Do not load and log containerBuild properties when executing in container
#--------------------------------------------------------------------------
if ( $ACTION -eq 'container_build' ) {

	Write-Host "`n[$scriptName] ACTION = $ACTION, Executing build in container..."

} else {

	#--------------------------------------------------------------------------
	# 2.6.2 Only log container properties if set
	#--------------------------------------------------------------------------
	$loggingList = @()
	
	if ( $env:CDAF_SKIP_CONTAINER_BUILD ) {
		$loggingList += "[$scriptName]   CDAF_SKIP_CONTAINER_BUILD : $env:CDAF_SKIP_CONTAINER_BUILD"
	} else {	
		$env:CDAF_SKIP_CONTAINER_BUILD = getProp 'CDAF_SKIP_CONTAINER_BUILD' "$SOLUTIONROOT\CDAF.solution"
		if ( $env:CDAF_SKIP_CONTAINER_BUILD ) {
			$loggingList += "[$scriptName]   CDAF_SKIP_CONTAINER_BUILD : $env:CDAF_SKIP_CONTAINER_BUILD (defined in $SOLUTIONROOT\CDAF.solution)"
		}
	}

	if ( $env:CDAF_DOCKER_REQUIRED ) {
		$loggingList += "[$scriptName]   CDAF_DOCKER_REQUIRED      : $env:CDAF_DOCKER_REQUIRED"
	} else {	
		$env:CDAF_DOCKER_REQUIRED = getProp 'CDAF_DOCKER_REQUIRED' "$SOLUTIONROOT\CDAF.solution"
		if ( $env:CDAF_DOCKER_REQUIRED ) {
			$loggingList += "[$scriptName]   CDAF_DOCKER_REQUIRED      : $env:CDAF_DOCKER_REQUIRED (defined in $SOLUTIONROOT\CDAF.solution)"
		}
	}

	# 1.6.7 Container Build process
	$containerBuild = getProp 'containerBuild' "$SOLUTIONROOT\CDAF.solution"
	$containerImage = getProp 'containerImage' "$SOLUTIONROOT\CDAF.solution"
	if ( $containerImage ) {
		if (($env:CONTAINER_IMAGE) -or ($CONTAINER_IMAGE)) {
			$loggingList += "[$scriptName]   containerImage            : $containerImage"
			if ($env:CONTAINER_IMAGE) {
				$loggingList += "[$scriptName]   CONTAINER_IMAGE           : $env:CONTAINER_IMAGE (not changed as already set)"
			} else {
				$env:CONTAINER_IMAGE = $CONTAINER_IMAGE
				$loggingList += "[$scriptName]   CONTAINER_IMAGE           : $env:CONTAINER_IMAGE (loaded from `$CONTAINER_IMAGE)"
			}
		} else {
			$env:CONTAINER_IMAGE = $containerImage
			$loggingList += "[$scriptName]   CONTAINER_IMAGE           : $env:CONTAINER_IMAGE (set from containerImage in `$SOLUTIONROOT\CDAF.solution)"
		}

		# 2.6.1 default containerBuild process
		if (! ( $containerBuild )) {
			$containerBuild = '& ${AUTOMATIONROOT}/processor/containerBuild.ps1 $SOLUTION $BUILDNUMBER $REVISION $ACTION'
			$defaultCBProcess = '(default) '
		}
	}

	if ( $containerBuild ) {
		$loggingList += "[$scriptName]   containerBuild            : $containerBuild $defaultCBProcess"
	} else {
		$loggingList += "[$scriptName]   containerBuild            : (not defined in $SOLUTIONROOT\CDAF.solution)"
	}

	# 2.2.0 Image Build as incorperated function
	$buildImage = getProp 'buildImage' "$SOLUTIONROOT\CDAF.solution"
	$imageBuild = getProp 'imageBuild' "$SOLUTIONROOT\CDAF.solution"
	if ( $buildImage ) {
		$loggingList += "[$scriptName]   buildImage                : $buildImage"
		# 2.6.1 imageBuild mimimum configuration, with default process
		if ( ! $imageBuild ) {
			$imageBuild = '& $AUTOMATIONROOT/remote/imageBuild.ps1 ${SOLUTION}_${REVISION} ${BUILDNUMBER} ${buildImage} ${LOCAL_WORK_DIR}'
			$defaultIBProcess = '(default) '
		}
	}

	if ( $imageBuild ) {
		$loggingList += "[$scriptName]   imageBuild                : $imageBuild $defaultIBProcess"
	}

	#----------------------------------------------------------------
	# Properties Loaded, perform container execution validation steps
	#----------------------------------------------------------------
	if ( $containerBuild ) {
		# 2.5.5 support conditional containerBuild based on environment variable
		if ( $ACTION -eq 'skip_container_build' ) {
			$loggingList += "[$scriptName]   ACTION                    : $ACTION, container build defined but skipped ..."
			Clear-Variable -Name 'containerBuild'
		}
		if ( $env:CDAF_SKIP_CONTAINER_BUILD ) {
			$loggingList += "[$scriptName]   CDAF_SKIP_CONTAINER_BUILD : $env:CDAF_SKIP_CONTAINER_BUILD, container build defined but skipped ..."
			Clear-Variable -Name 'containerBuild'
		}
	}

	if (( $containerBuild ) -or ( $imageBuild )) {
		$versionTest = cmd /c docker --version 2`>`&1
		if ( $LASTEXITCODE -ne 0 ) {
			$error.clear()
			cmd /c "exit 0"
			if ( $env:CDAF_DOCKER_REQUIRED ) {
				Write-Host "`n[$scriptName] CDAF Container Features Set ..."
				Write-Output $loggingList
				ERRMSG "[DOCKE_REQ] Docker not installed, but `$env:CDAF_DOCKER_REQUIRED = ${env:CDAF_DOCKER_REQUIRED}, so halting!" 8911
			} else {
				$loggingList += "[$scriptName]   Docker                    : (not installed, will attempt to execute natively)"
				if ( $containerBuild ) {
					Clear-Variable -Name 'containerBuild'
				}
				if ( $imageBuild ) {
					Clear-Variable -Name 'imageBuild'
				}
			}
		} else {
			$array = $versionTest.split(" ")
			$dockerVersion = $array[2].TrimEnd(',')
			$dockerSystem = $array[0]

			if ( $dockerSystem -eq 'nerdctl' ) {
				$loggingList += "[$scriptName]   Docker                    : $dockerVersion (containerd)"
			} elseif ( Get-Service Docker -ErrorAction SilentlyContinue ) { # Check if Docker is running
				$dockerStatus = (Get-Service Docker).Status
				if ( $dockerStatus -eq 'Running' ) {
					# docker-desktop test
					$imageTest = cmd /c docker images 2`>`&1
					if ( $LASTEXITCODE -eq 0 ) {
						$loggingList += "[$scriptName]   Docker                    : $dockerVersion"
					} else {
						if ( $env:CDAF_DOCKER_REQUIRED ) {
							Write-Host "`n[$scriptName] CDAF Container Features Set ..."
							Write-Output $loggingList
							ERRMSG "[DOCKER_NOT_RUNNING] Docker installed and running, but not responding (perhaps docker-desktop not started?). `$env:CDAF_DOCKER_REQUIRED = ${env:CDAF_DOCKER_REQUIRED}, so halting!" 8911
						} else {
							if ( ( $containerBuild ) -and ( $imageBuild )) {
								$loggingList += "[$scriptName]   Docker                    : $dockerVersion (running, but not responding, will attempt to execute natively and skip imageBuild process)"
								Clear-Variable -Name 'containerBuild'
								Clear-Variable -Name 'imageBuild'
							} else {
								if ( $containerBuild ) {
									$loggingList += "[$scriptName]   Docker                    : $dockerVersion (running, but not responding, will attempt to execute natively)"
									Clear-Variable -Name 'containerBuild'
								}
								if ( $imageBuild ) {
									$loggingList += "[$scriptName]   Docker                    : $dockerVersion (running, but not responding, will skip imageBuild process)"
									Clear-Variable -Name 'imageBuild'
								}
							}
						}
					}
				} else {
					if ( Get-Process dockerd -ea SilentlyContinue ) {
						$loggingList += "[$scriptName]   Docker                    : $dockerVersion"
					} else {
						executeExpression 'Start-Service Docker'
						$dockerStatus = (Get-Service Docker).Status
						$loggingList += "[$scriptName] $dockerStatus = $dockerStatus"
						if ( $dockerStatus -ne 'Running' ) {
							if ( $env:CDAF_DOCKER_REQUIRED ) {
								Write-Host "`n[$scriptName] CDAF Container Features Set ..."
								Write-Output $loggingList
								ERRMSG "[DOCKERSTART] Unable to start Docker, `$dockerStatus = $dockerStatus" 8910
							} else {
								if ( ( $containerBuild ) -and ( $imageBuild )) {
									$loggingList += "[$scriptName]   Docker                    : $dockerVersion (not running, will attempt to execute natively and skip imageBuild process)"
									Clear-Variable -Name 'containerBuild'
									Clear-Variable -Name 'imageBuild'
								} else {
									if ( $containerBuild ) {
										$loggingList += "[$scriptName]   Docker                    : $dockerVersion (installed but not running, will attempt to execute natively)"
										Clear-Variable -Name 'containerBuild'
									}
									if ( $imageBuild ) {
										$loggingList += "[$scriptName]   Docker                    : $dockerVersion (installed but not running, will skip imageBuild process)"
										Clear-Variable -Name 'imageBuild'
									}
								}
							}
						}
					}
				}

			} else {

				if ( $env:CDAF_DOCKER_REQUIRED ) {
					Write-Host "`n[$scriptName] CDAF Container Features Set ..."
					Write-Output $loggingList
					ERRMSG "[DOCKER_SERVICE_NOT_FOUND] Docker installed but service not found (perhaps docker-desktop not started?). `$env:CDAF_DOCKER_REQUIRED = ${env:CDAF_DOCKER_REQUIRED}, so halting!" 8911
				} else {
					if (( $containerBuild ) -and ( $imageBuild )) {
						$loggingList += "[$scriptName]   Docker                    : $dockerVersion (Docker installed but service not found, will attempt to execute natively and skip imageBuild process)"
						Clear-Variable -Name 'containerBuild'
						Clear-Variable -Name 'imageBuild'
					} else {
						if ( $containerBuild ) {
							$loggingList += "[$scriptName]   Docker                    : $dockerVersion (Docker installed but service not found, will attempt to execute natively)"
							Clear-Variable -Name 'containerBuild'
						}
						if ( $imageBuild ) {
							$loggingList += "[$scriptName]   Docker                    : $dockerVersion (Docker installed but service not found, will skip imageBuild process)"
							Clear-Variable -Name 'imageBuild'
						}
					}
				}
			}
		}
	}

	if ( $loggingList ) {
		Write-Host "`n[$scriptName] CDAF Container Features Set ..."
		Write-Output $loggingList
	}
}

#--------------------------------------------------------------------------
# Start build process
#--------------------------------------------------------------------------

# 2.4.4 Pre-Build Tasks, exclude from container_build to avoid performing twice
if (( Test-Path "$prebuild" ) -and ( $ACTION -ne 'container_build' )) {
	Write-Host "`n[$scriptName] Process Pre-Build Task ...`n"
	& "$AUTOMATIONROOT\remote\execute.ps1" $SOLUTION $BUILDNUMBER "package" "$prebuild" $ACTION
	if(!$?){ exceptionExit ".$AUTOMATIONROOT\remote\execute.ps1 $SOLUTION $BUILDNUMBER `"package`" `"$prebuild`" $ACTION" }
}

if (( $containerBuild ) -and ( $ACTION -ne 'packageonly' )) {

	Write-Host "`n[$scriptName] Execute container build ${defaultCBProcess}...`n" -ForegroundColor Green
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
		executeExpression "& `"$AUTOMATIONROOT\buildandpackage\buildProjects.ps1`" $SOLUTION $BUILDNUMBER $REVISION `"$AUTOMATIONROOT`" `"$SOLUTIONROOT`" $ACTION"
	}

	# 2.4.4 Process optional post build, pre-packaging tasks
	if (Test-Path "$postbuild") {
		Write-Host "`n[$scriptName] Process Post-Build Task ...`n"
		& "$AUTOMATIONROOT\remote\execute.ps1" $SOLUTION $BUILDNUMBER "package" "$postbuild" $ACTION
		if(!$?){ exceptionExit ".$AUTOMATIONROOT\remote\execute.ps1 $SOLUTION $BUILDNUMBER `"package`" `"$postbuild`" $ACTION" }
	}

	# 2.4.4 Process optional post build, pre-packaging process
	$postBuild = getProp 'postBuild' "$SOLUTIONROOT\CDAF.solution"  
	if ( $postBuild ) {
		executeExpression "$postBuild"
	}

	if (( $ACTION -eq 'buildonly' ) -or ( $ACTION -eq 'clean' )) {
		Write-Host "`n[$scriptName] ACTION is $ACTION so skipping package process" -ForegroundColor Yellow
	} else {
		Write-Host
		executeExpression "& `"$AUTOMATIONROOT\buildandpackage\package.ps1`" $SOLUTION $BUILDNUMBER $REVISION `"$AUTOMATIONROOT`" `"$SOLUTIONROOT`" $LOCAL_WORK_DIR $REMOTE_WORK_DIR $ACTION"
	}
}
	
#-------------------------------------------------------
# Build process complete, start image and file packaging
#-------------------------------------------------------

if ( $ACTION -ne 'container_build' ) {

	# 2.2.0 Image Build as an incorperated function, no longer conditional on containerBuild, but do not attempt if within containerbuild
	if ( $imageBuild ) {
		Write-Host "[$scriptName] Execute image build ${defaultIBProcess}..."
		if ( $skipImageBuild ) { # docker test already performed
			Write-Host "[$scriptName] $skipImageBuild"
		} else {
			if ( ! ( $buildImage )) {
				# If an explicit image is not defined, perform implicit cascading load
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
			}
	
			$constructor = getProp 'constructor' "$SOLUTIONROOT\CDAF.solution"
			if ( $constructor ) {
				Write-Host "[$scriptName]   constructor   = $constructor"
			}
			executeExpression "$imageBuild"
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

			$packageMethod = getProp 'packageMethod' "$SOLUTIONROOT\CDAF.solution"
			if ( $packageMethod -eq 'tarball' ) {
				$compressedArtefact = "${artifactID}.tar.gz"
				$NewFileToAdd = "${SOLUTION}-${BUILDNUMBER}.zip"
				if ( Test-Path $NewFileToAdd ) {
					executeExpression "Move-Item $NewFileToAdd $artifactID"
				}
				executeExpression "cd $artifactID"
				executeExpression "tar -czf ../${compressedArtefact} ."
				executeExpression "cd .."
				$SourceFile = (get-item "${compressedArtefact}").FullName
			} else {
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
			}

			Write-Host "[$scriptName]   Create single script artefact release.ps1"
			$SourceFile = (get-item ${compressedArtefact}).FullName
			[IO.File]::WriteAllBytes("$pwd\release.ps1",[char[]][Convert]::ToBase64String([IO.File]::ReadAllBytes($SourceFile)))
			$base64 = get-content "release.ps1"

			Set-Content "release.ps1" 'Param ('
			Add-Content "release.ps1" '  [string]$ENVIRONMENT,'
			Add-Content "release.ps1" '  [string]$RELEASE,'
			Add-Content "release.ps1" '  [string]$OPT_ARG'
			Add-Content "release.ps1" ')'
			Add-Content "release.ps1" 'Import-Module Microsoft.PowerShell.Utility'
			Add-Content "release.ps1" 'Import-Module Microsoft.PowerShell.Management'
			Add-Content "release.ps1" 'Import-Module Microsoft.PowerShell.Security'
			Add-Content "release.ps1" 'Write-Host "Launching release.ps1 (${artifactPrefix}.${BUILDNUMBER}) ..."'
			Add-Content "release.ps1" "`$Base64 = `"$base64`""
			Add-Content "release.ps1" 'if ( Test-Path "TasksLocal" ) { Remove-Item -Recurse TasksLocal }'
			Add-Content "release.ps1" "Remove-Item ${SOLUTION}*.zip" # remote package
			Add-Content "release.ps1" 'Write-Host "[$(Get-Date)] Extracting embedded package file ..."'
			Add-Content "release.ps1" "[IO.File]::WriteAllBytes(`"`$pwd\${compressedArtefact}`",[System.Convert]::FromBase64String(`$Base64))"

			Add-Content "release.ps1" 'Write-Host "[$(Get-Date)] Decompressing package file ..."'
			if ( $packageMethod -eq 'tarball' ) {
				Add-Content "release.ps1" "tar -zxf ${compressedArtefact}"
			} else {
				# TODO conditional for PS core in the future Add-Content "release.ps1" "Set-Content -Path '${compressedArtefact}' -Value `$Content -AsByteStream"
				Add-Content "release.ps1" 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
				Add-Content "release.ps1" "[System.IO.Compression.ZipFile]::ExtractToDirectory(`"`$PWD\${compressedArtefact}`", `"`$PWD`")"
			}

			Add-Content "release.ps1" 'Write-Host "[$(Get-Date)] Execute Deployment ..."'
			Add-Content "release.ps1" '.\TasksLocal\delivery.bat "$ENVIRONMENT" "$RELEASE" "$OPT_ARG"'
			Add-Content "release.ps1" 'exit $LASTEXITCODE'
			$artefactList = @('release.ps1')
		}
	} else {
		$artefactList = @(Get-ChildItem *.zip)
		$artefactList += "$(Get-Location)\TasksLocal\"
	}

	foreach ( $object in $artefactList ) {
		if ( (Get-Item $object) -is [System.IO.DirectoryInfo] ) {
			$FileSize += (Get-ChildItem $object | Measure-Object -Property Length -sum).Sum
		} else {
			$FileSize += (get-item $object).Length/1MB
		}
	}
	Write-Host "[$(Get-Date)] Created $artefactList, MB : $FileSize"
	
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


	if (( $ACTION -eq 'buildonly' ) -or ( $ACTION -eq 'clean' )) {
		Write-Host "`n[$scriptName][$(Get-Date)] $ACTION complete." -ForegroundColor Green
	} else {
		Write-Host "`n[$scriptName][$(Get-Date)] Process complete, artefacts [${artefactList}] placed in $stageTarget" -ForegroundColor Green
	}
}

$error.clear()
exit 0