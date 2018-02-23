# Entry Point for portable package deployment, child scripts inherit the functions of parent scripts, so these definitions are global
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
    echo $exception.Exception|format-list -force
    write-host "[$scriptName] Returning errorlevel (500) to DOS" -ForegroundColor Magenta
    $host.SetShouldExit(500); exit
}

# Not used in this script because called from DOS, but defined here for all child scripts
function taskFailure ($taskName) {
    write-host
    write-host "[$scriptName] Failure occured! Code returned ... $taskName" -ForegroundColor Red
    write-host "[$scriptName] Returning errorlevel (510) to DOS" -ForegroundColor Magenta
    $host.SetShouldExit(510)
	exit 510
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

$TARGET    = $args[0]
$WORKSPACE = $args[1]

# $myInvocation.MyCommand.Name not working when processing DOS
$scriptName = "executeTasks.ps1"

write-host "[$scriptName]   TARGET               : $TARGET"
if ($WORKSPACE ) {
    write-host "[$scriptName]   WORKSPACE            : $(pwd) (passed as argument)"
} else {
    write-host "[$scriptName]   WORKSPACE            : $(pwd)"
}

write-host "[$scriptName]   hostname             : $(hostname)"
write-host "[$scriptName]   whoami               : $(whoami)"

write-host "`n[$scriptName] Load SOLUTION and BUILDNUMBER from manifest.txt"
& .\Transform.ps1 ".\manifest.txt" | ForEach-Object { invoke-expression $_ }

$scriptOverride = getProp ("deployScriptOverride")
if ($scriptOverride ) {
	write-host "[$scriptName]   deployScriptOverride : $scriptOverride`n"
    $expression=".\$scriptOverride $SOLUTION $BUILDNUMBER $TARGET"
    write-host $expression
	try {
		Invoke-Expression $expression
		if($LASTEXITCODE -ne 0){
		    exitWithCode "OVERRIDE_EXECUTE_NON_ZERO_EXIT Invoke-Expression $expression" $LASTEXITCODE 
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
	    & .\execute.ps1 $SOLUTION $BUILDNUMBER $TARGET $taskItem
		if($LASTEXITCODE -ne 0){
		    exitWithCode "OVERRIDE_EXECUTE_NON_ZERO_EXIT & .\execute.ps1 $SOLUTION $BUILDNUMBER $TARGET $taskItem" $LASTEXITCODE 
		}
	    if(!$?){ taskFailure "POWERSHELL_TRAP" }
    }
}