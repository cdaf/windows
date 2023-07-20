
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
		Write-Host "`n[$scriptName] Exit with LASTEXITCODE = $exitcode`n" -ForegroundColor Red
		exit $exitcode
	}
}

function exceptionExit ($exception) {
    write-host "[$scriptName]   Exception details follow ..." -ForegroundColor Red
    Write-Output $exception.Exception|format-list -force
    write-host "[$scriptName] Returning errorlevel (500) to DOS" -ForegroundColor Magenta
    $host.SetShouldExit(500); exit
}

# Not used in this script because called from DOS, but defined here for all child scripts
function taskFailure ($taskName, $exitCode) {
    if (!( $exitCode )) {
        $exitCode = 510
    }
    write-host "`n[$scriptName] Failure occured! Code returned ... $taskName" -ForegroundColor Red
    write-host "[$scriptName] Returning errorlevel ($exitCode) to DOS" -ForegroundColor Magenta
    $host.SetShouldExit($exitCode)
	exit $exitCode
}

function taskWarning { 
    write-host "[$scriptName] Warning, $taskName encountered an error that was allowed to proceed." -ForegroundColor Yellow
}

function getProp ($propName) {

	try {
		$propValue=$(& .\getProperty.ps1 .\$TARGET $propName)
		if(!$?){ taskWarning }
	} catch { exceptionExit $_ }
	
    return $propValue
}

$TARGET  = $args[0]
$RELEASE = $args[1]
$OPT_ARG = $args[2]

# $myInvocation.MyCommand.Name not working when processing DOS
$scriptName = "executeTasks.ps1"

write-host "[$scriptName]   TARGET    : $TARGET"

if ( $RELEASE ) {
    write-host "[$scriptName]   RELEASE   : $RELEASE"
} else {
	if ( $env:RELEASE ) {
		$RELEASE = $env:RELEASE
	    write-host "[$scriptName]   RELEASE   : $RELEASE (from environment variable)"
	} else {
	    write-host "[$scriptName]   RELEASE   : (not supplied)"
	}
}

if ( $OPT_ARG ) {
    write-host "[$scriptName]   OPT_ARG   : $OPT_ARG"
} else {
	if ( $env:OPT_ARG ) {
		$OPT_ARG = $env:OPT_ARG
	    write-host "[$scriptName]   OPT_ARG   : $OPT_ARG (from environment variable)"
	else
	    write-host "[$scriptName]   OPT_ARG   : (not supplied)"
	}
}

$WORKSPACE = $(Get-Location)
write-host "[$scriptName]   WORKSPACE : $WORKSPACE (pwd)"

$CDAF_CORE = $(pwd)
Write-Host "[$scriptName]   CDAF_CORE : $CDAF_CORE"

write-host "[$scriptName]   hostname  : $(hostname)"
write-host "[$scriptName]   whoami    : $(whoami)"

write-host "`n[$scriptName] Load SOLUTION and BUILDNUMBER from manifest.txt"
& "$CDAF_CORE\Transform.ps1" ".\manifest.txt" | ForEach-Object { invoke-expression $_ }

$scriptOverride = getProp ("deployScriptOverride")
if ($scriptOverride ) {
	write-host "[$scriptName]   deployScriptOverride : $scriptOverride`n"
    $expression=".\$scriptOverride $SOLUTION $BUILDNUMBER $TARGET $OPT_ARG"
    write-host $expression
	try {
		Invoke-Expression $expression
		if($LASTEXITCODE -ne 0){
		    ERRMSG "OVERRIDE_EXECUTE_NON_ZERO_EXIT Invoke-Expression $expression" $LASTEXITCODE 
		}
	    if(!$?){ taskFailure "REMOTE_OVERRIDESCRIPT_TRAP" }
    } catch { exceptionExit $_ }

} else {

    $taskOverride = getProp "deployTaskOverride"
    if ($taskOverride ) {
	    $taskList = $taskOverride
    } else {
	    $taskList = "tasksRunRemote.tsk"
    }

	foreach ( $taskItem in $taskList.Split() ) {
	    write-host "`n[$scriptName] --- Executing $taskItem ---`n" -ForegroundColor Green
	    & "$CDAF_CORE\execute.ps1" $SOLUTION $BUILDNUMBER $TARGET $taskItem $OPT_ARG
		if($LASTEXITCODE -ne 0){
		    ERRMSG "OVERRIDE_EXECUTE_NON_ZERO_EXIT & .\execute.ps1 $SOLUTION $BUILDNUMBER $TARGET $taskItem $OPT_ARG" $LASTEXITCODE 
		}
	    if(!$?){ taskFailure "POWERSHELL_TRAP" }
    }
}