# Entry Point for Build Process, child scripts inherit the functions of parent scripts, so these definitions are global for the CD process
Param (
	[string]$ENVIRONMENT,
	[string]$RELEASE,
	[string]$OPT_ARG,
	[string]$WORK_DIR_DEFAULT,
	[string]$SOLUTION,
	[string]$BUILDNUMBER
)

Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Security

# Initialise
cmd /c "exit 0"
$Error.clear()
$env:CDAF_AUTOMATION_ROOT = ''
$env:CONTAINER_IMAGE = ''
$scriptName = 'delivery.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression "$expression 2> `$null"
	    if(!$?) { Write-Host "`n[$scriptName][TRAP] `$? = $?"; $error ; exit 1311 }
	} catch {
		Write-Host "`n[$scriptName][EXCEPTION] List exception and error array (if populated) and exit with LASTEXITCODE 1312" -ForegroundColor Red
		Write-Host $_.Exception|format-list -force
		if ( $error ) { Write-Host "[$scriptName][ERROR]   `$Error = $Error" ; $Error.clear() }
		exit 1312
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "`n[$scriptName][EXIT] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red
			if ( $error ) { Write-Host "[$scriptName][EXIT]   `$Error = $Error" ; $Error.clear() }
			exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				Write-Host "[$scriptName][WARN]   `$Error = $Error" ; $Error.clear()
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				Write-Host "`n[$scriptName][ERROR] `$Error = $error"; $Error.clear()
				Write-Host "[$scriptName][ERROR]   `$env:CDAF_IGNORE_WARNING is 'no' so exiting with LASTEXITCODE 1313 ..."; exit 1313
	    	} else {
		    	Write-Host "[$scriptName][WARN] `$Error = $error" ; $Error.clear()
	    	}
		}
	}
}

# Primary powershell, returns exitcode to DOS
function exceptionExit ( $identifier, $exception, $exitCode ) {
    write-host "`n[delivery.ps1] CDAF_DELIVERY_FAILURE.EXCEPTION : Exception in ${identifier}, details follow ..." -ForegroundColor Magenta
    Write-Output $exception.Exception | format-list -force
    if ( $exitCode ) {
		$host.SetShouldExit($exitCode)
		exit $exitCode
    } else {
		$host.SetShouldExit(2050)
		exit 2050
	}
}

function passExitCode ( $message, $exitCode ) {
    write-host "[delivery.ps1] $message" -ForegroundColor Red
    write-host "[delivery.ps1] CDAF_DELIVERY_FAILURE.EXIT : Exiting with `$LASTEXITCODE $exitCode" -ForegroundColor Magenta
    if ( $exitCode ) {
		$host.SetShouldExit($exitCode)
		exit $exitCode
    } else {
		$host.SetShouldExit(2051)
		exit 2051
	}
}

function taskFailure ($taskName) {
    write-host "`n[delivery.ps1] $taskName" -ForegroundColor Red
	write-host "[delivery.ps1] CDAF_DELIVERY_FAILURE.INTERNAL_TASK : `$host.SetShouldExit(2051)" -ForegroundColor Red
	$host.SetShouldExit(2052)
	exit 2052
}

function taskWarning { 
    write-host "[delivery.ps1] Warning, $taskName encountered an error that was allowed to proceed." -ForegroundColor Yellow
}

function itemRemove ($itemPath) { 
	if ( Test-Path $itemPath ) {
		write-host "[delivery.ps1] Delete $itemPath"
		Remove-Item $itemPath -Recurse 
		if(!$?){ taskFailure("Remove-Item $itemPath") }
	}
}

function pathTest ($pathToTest) { 
	if ( Test-Path $pathToTest ) {
		Write-Host "found ($pathToTest)"
	} else {
		Write-Host "none ($pathToTest)"
	}
}

function taskError ($taskName) {
    write-host "[delivery.ps1] Error occured when excuting $taskName" -ForegroundColor Red
    write-host "[delivery.ps1] CDAF_DELIVERY_FAILURE.INTERNAL_TASK_ERROR : Exit with `$LASTEXITCODE 70" -ForegroundColor Red
    $host.SetShouldExit(70); exit 70
}

function getProp ($propName) {

	try {
		$propValue=$(& $WORK_DIR_DEFAULT\getProperty.ps1 $propertiesFile $propName)
		if(!$?){ taskWarning }
	} catch { exceptionExit $_ 2060 }
	
    return $propValue
}

function getFilename ($FullPathName) {

	$PIECES=$FullPathName.split('\') 
	$NUMBEROFPIECES=$PIECES.Count 
	$FILENAME=$PIECES[$NumberOfPieces-1] 
	$DIRECTORYPATH=$FullPathName.Trim($FILENAME) 
	return $FILENAME

}

if ( $ENVIRONMENT ) {
	Write-Host "[$scriptName]   ENVIRONMENT      : $ENVIRONMENT"
} else { 
	Write-Host "[$scriptName] ENVIRONMENT_NOT_SUPPLIED Environment not supplied!" -ForegroundColor Red
    write-host "[$scriptName]   `$host.SetShouldExit(51)" -ForegroundColor Red
    $host.SetShouldExit(51); exit
}

if ( $RELEASE ) {
	Write-Host "[$scriptName]   RELEASE          : $RELEASE"
} else {
	$RELEASE = 'Release'
	Write-Host "[$scriptName]   RELEASE          : $RELEASE (default)"
}

Write-Host "[$scriptName]   OPT_ARG          : $OPT_ARG"

if ( $WORK_DIR_DEFAULT ) {
	Write-Host "[$scriptName]   WORK_DIR_DEFAULT : $WORK_DIR_DEFAULT"
} else {
	$WORK_DIR_DEFAULT = 'TasksLocal'
	Write-Host "[$scriptName]   WORK_DIR_DEFAULT : $WORK_DIR_DEFAULT (default)"
}

if ($SOLUTION) {
	Write-Host "[$scriptName]   SOLUTION         : $SOLUTION"
} else {
	$propertiesFile = "$WORK_DIR_DEFAULT\manifest.txt"
	$SOLUTION = getProp 'SOLUTION'
	if ($SOLUTION) {
		Write-Host "[$scriptName]   SOLUTION         : $SOLUTION (from $WORK_DIR_DEFAULT\manifest.txt)"
	} else {
		Write-Host "[$scriptName] DELIVERY_SOLUTION_NOT_FOUND Solution not supplied and unable to derive from manifest.txt"
	    write-host "[$scriptName]   `$host.SetShouldExit(54)" -ForegroundColor Red
	    $host.SetShouldExit(54); exit
	}
}

if ($BUILDNUMBER) {
	Write-Host "[$scriptName]   BUILDNUMBER      : $BUILDNUMBER"
} else {
	$propertiesFile = "$WORK_DIR_DEFAULT\manifest.txt"
	$BUILDNUMBER = getProp 'BUILDNUMBER'
	if ($BUILDNUMBER) {
		Write-Host "[$scriptName]   BUILDNUMBER      : $BUILDNUMBER (from $WORK_DIR_DEFAULT\manifest.txt)"
	} else {
		Write-Host "[$scriptName] DELIVERY_BUILD_NUMBER_NOT_FOUND Build number not supplied and unable to derive from manifest.txt"
	    write-host "[$scriptName]   `$host.SetShouldExit(55)" -ForegroundColor Red
	    $host.SetShouldExit(55); exit
	}
}

# Runtime information
$landingDir = "$(Get-Location)"
Write-Host "[$scriptName]   pwd              : $landingDir"
Write-Host "[$scriptName]   hostname         : $(hostname)" 
Write-Host "[$scriptName]   whoami           : $(whoami)"

$propertiesFile = "$WORK_DIR_DEFAULT\CDAF.properties"
$cdafVersion = getProp 'productVersion'
Write-Host "[$scriptName]   CDAF Version     : $cdafVersion"

$propertiesFile = "$WORK_DIR_DEFAULT\manifest.txt"
$processSequence = getProp 'processSequence'

if ( $processSequence ) {
	Write-Host "[$scriptName]   processSequence  : $processSequence (override)"
} else {
	$processSequence = 'remoteTasks.ps1 localTasks.ps1'
}

# The containerDeploy is an extension to remote tasks, which means recursive call to this script should not happen (unlike containerBuild)
# containerDeploy example & ${env:CDAF_WORKSPACE}/containerDeploy.ps1 "${ENVIRONMENT}" "${RELEASE}" "${SOLUTION}" "${BUILDNUMBER}" "${REVISION}"
$containerDeploy = getProp 'containerDeploy'
$REVISION = getProp 'REVISION'
if ( $containerDeploy ) {
	# To support environment dependent containerDeploy, e.g. only on the build server, allow setting as variable
	$containerDeploy = Invoke-Expression "Write-Output `"$containerDeploy`""
	if ( $containerDeploy ) {
		${env:CONTAINER_IMAGE} = getProp 'containerImage'
		${env:CDAF_WORKSPACE} = "$(Get-Location)/${WORK_DIR_DEFAULT}"
		Set-Location "${env:CDAF_WORKSPACE}"
		Write-Host
		executeExpression "$containerDeploy"
		Set-Location "$landingDir"
	}
}

if (!( $containerDeploy )) {
	foreach ($step in $processSequence.Split()) {
		Write-Host
		executeExpression "& .\$WORK_DIR_DEFAULT\$step '$ENVIRONMENT' '$BUILDNUMBER' '$SOLUTION' '$WORK_DIR_DEFAULT' '$OPT_ARG'"
	}
}