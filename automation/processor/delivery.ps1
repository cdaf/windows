# Entry Point for Delivery Process, child scripts inherit the functions of parent scripts, so these definitions are global for the CD process
Param (
	[string]$ENVIRONMENT,
	[string]$RELEASE,
	[string]$OPT_ARG,
	[string]$WORK_DIR_DEFAULT
)

Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Security

# Initialise
cmd /c "exit 0"
$Error.clear()
$scriptName = 'delivery.ps1'

# Consolidated Error processing function
#  required : error message
#  optional : exit code, if not supplied only error message is written
function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		if ( $exitcode ) {
			Write-Host "`n[$scriptName]$message" -ForegroundColor Red
		} else {
			Write-Host "`n[$scriptName] ERRMSG triggered without message parameter." -ForegroundColor Red
		}
	} else {
		if ( $exitcode ) {
			Write-Warning "`n[$scriptName]$message"
		} else {
			Write-Warning "`n[$scriptName] ERRMSG triggered without message parameter."
		}
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
			try {
				Invoke-Expression $env:CDAF_ERROR_DIAG
			    if(!$?) { Write-Host "[CDAF_ERROR_DIAG] `$? = $?" }
			} catch {
				$message = $_.Exception.Message
				$_.Exception | format-list -force
			}
		    if ( $LASTEXITCODE ) {
		    	if ( $LASTEXITCODE -ne 0 ) {
					Write-Host "[CDAF_ERROR_DIAG][EXIT] `$LASTEXITCODE is $LASTEXITCODE"
				}
			}
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
	$ENVIRONMENT = Invoke-Expression "Write-Output $ENVIRONMENT"
	$env:CDAF_CD_ENVIRONMENT = $ENVIRONMENT
} else { 
	Write-Host "[$scriptName] ENVIRONMENT_NOT_SUPPLIED Environment not supplied!" -ForegroundColor Red
    write-host "[$scriptName]   `$host.SetShouldExit(51)" -ForegroundColor Red
    $host.SetShouldExit(51); exit
}

if ( $RELEASE ) {
	Write-Host "[$scriptName]   RELEASE          : $RELEASE"
	$RELEASE = Invoke-Expression "Write-Output $RELEASE"
} else {
	$RELEASE = 'Release'
	Write-Host "[$scriptName]   RELEASE          : $RELEASE (default)"
}
$env:CDAF_CD_RELEASE = $RELEASE

if ( $OPT_ARG ) {
	Write-Host "[$scriptName]   OPT_ARG          : $OPT_ARG"
	$OPT_ARG = Invoke-Expression "Write-Output $OPT_ARG"
	$env:CDAF_CD_OPT_ARG = $OPT_ARG
} else {
	Write-Host "[$scriptName]   OPT_ARG          : (not supplied)"
}

if ( $WORK_DIR_DEFAULT ) {
	Write-Host "[$scriptName]   WORK_DIR_DEFAULT : $WORK_DIR_DEFAULT"
} else {
	$WORK_DIR_DEFAULT = 'TasksLocal'
	Write-Host "[$scriptName]   WORK_DIR_DEFAULT : $WORK_DIR_DEFAULT (default)"
}
if ( Test-Path $WORK_DIR_DEFAULT ) {
	$WORK_DIR_DEFAULT = (Get-Item $WORK_DIR_DEFAULT).FullName
} else {
	Write-Host "[$scriptName] WORK_DIR_DEFAULT not found!" -ForegroundColor Red
    write-host "[$scriptName]   `$host.SetShouldExit(52)" -ForegroundColor Red
    $host.SetShouldExit(52); exit
}

$CDAF_CORE = "$WORK_DIR_DEFAULT"
Write-Host "[$scriptName]   CDAF_CORE        : $CDAF_CORE"

$propertiesFile = "$WORK_DIR_DEFAULT\manifest.txt"
$SOLUTION = getProp 'SOLUTION'
if ( $SOLUTION ) {
	Write-Host "[$scriptName]   SOLUTION         : $SOLUTION (from manifest.txt)"
} else {
	Write-Host "[$scriptName] DELIVERY_SOLUTION_NOT_FOUND Solution not supplied and unable to derive from manifest.txt"
	write-host "[$scriptName]   `$host.SetShouldExit(54)" -ForegroundColor Red
	$host.SetShouldExit(54); exit
}

$propertiesFile = "$WORK_DIR_DEFAULT\manifest.txt"
$BUILDNUMBER = getProp 'BUILDNUMBER'
if ( $BUILDNUMBER ) {
	Write-Host "[$scriptName]   BUILDNUMBER      : $BUILDNUMBER (from manifest.txt)"
} else {
	Write-Host "[$scriptName] DELIVERY_BUILD_NUMBER_NOT_FOUND Build number not supplied and unable to derive from manifest.txt"
	write-host "[$scriptName]   `$host.SetShouldExit(55)" -ForegroundColor Red
	$host.SetShouldExit(55); exit
}

$WORKSPACE_ROOT = (Get-Location).Path
Write-Host "[$scriptName]   WORKSPACE_ROOT   : ${WORKSPACE_ROOT}"
Write-Host "[$scriptName]   whoami           : $(whoami)"
Write-Host "[$scriptName]   hostname         : $(hostname)" 

$propertiesFile = "$WORK_DIR_DEFAULT\CDAF.properties"
$cdafVersion = getProp 'productVersion'
Write-Host "[$scriptName]   CDAF Version     : $cdafVersion"

# 2.5.5 default error diagnostic command as solution property
if ( $env:CDAF_ERROR_DIAG ) {
	Write-Host "[$scriptName]   CDAF_ERROR_DIAG  : $CDAF_ERROR_DIAG"
} else {
	$env:CDAF_ERROR_DIAG = getProp 'CDAF_ERROR_DIAG' "$propertiesFile"
	if ( $env:CDAF_ERROR_DIAG ) {
		Write-Host "[$scriptName]   CDAF_ERROR_DIAG  : $CDAF_ERROR_DIAG (defined in $propertiesFile)"
	} else {
		Write-Host "[$scriptName]   CDAF_ERROR_DIAG  : (not set or defined in $propertiesFile)"
	}
}

$propertiesFile = "$WORK_DIR_DEFAULT\manifest.txt"
$processSequence = getProp 'processSequence'

if ( $processSequence ) {
	Write-Host "[$scriptName]   processSequence  : $processSequence (override)"
} else {
	$processSequence = 'remoteTasks.ps1 localTasks.ps1 containerTasks.ps1'
}

foreach ($step in $processSequence.Split()) {
	if ( $step ) {
		Write-Host
		executeExpression "& '$WORK_DIR_DEFAULT\$step' '$ENVIRONMENT' '$BUILDNUMBER' '$SOLUTION' '$WORK_DIR_DEFAULT' '$OPT_ARG'"
		Set-Location ${WORKSPACE_ROOT}
	}
}

Write-Host "`n[$scriptName] ========================================="
Write-Host "[$scriptName]        Delivery Process Complete"
