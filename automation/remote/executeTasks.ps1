function taskException ($taskName) {
    write-host "[$scriptName] Caught an exception executing $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($_.Exception.Message)" -ForegroundColor Red
	write-host
    throw "$scriptName HALT"
}

function exitWithCode ($taskName) {
    write-host
    write-host "[$scriptName] Caught an exception excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    write-host
    write-host "     Returning errorlevel (-1) to DOS" -ForegroundColor Magenta
    write-host
    $host.SetShouldExit(-1)
    exit
}

function taskWarning { 
    write-host "[$scriptName] Warning, $taskName encountered an error that was allowed to proceed." -ForegroundColor Yellow
}

function getProp ($propName) {

	try {
		$propValue=$(& .\getProperty.ps1 .\$TARGET $propName)
		if(!$?){ taskWarning }
	} catch { exitWithCode "getProp" }
	
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

write-host
write-host "[$scriptName] Load SOLUTION and BUILDNUMBER from manifest.txt"
& .\Transform.ps1 ".\manifest.txt" | ForEach-Object { invoke-expression $_ }

$scriptOverride = getProp ("deployScriptOverride")
if ($scriptOverride ) {
	write-host "[$scriptName]   deployScriptOverride : $scriptOverride"
    Write-Host
    $expression=".\$scriptOverride $SOLUTION $BUILDNUMBER $TARGET"
    write-host $expression
	try {
		Invoke-Expression $expression
	    if(!$?){ taskException "REMOTE_OVERRIDESCRIPT_TRAP" $_ }
    } catch { taskException "REMOTE_OVERRIDESCRIPT_EXCEPTION" $_ }


} else {

    $taskOverride = getProp "deployTaskOverride"
    if ($taskOverride ) {
	    $taskList = $taskOverride
	    write-host "[$scriptName]   taskList  : $taskList"
    } else {
	    $taskList = "tasksRunRemote.tsk"
	    write-host "[$scriptName]   taskList  : $taskList (default, deployTaskOverride not found in properties file)"
    }

    Write-Host
    write-host "[$scriptName] Execute the Tasks defined in $taskList"
    Write-Host
    try {
	    & .\execute.ps1 $SOLUTION $BUILDNUMBER $TARGET $taskList
	    if(!$?){ exitWithCode "POWERSHELL_TRAP_$_" }
    } catch { exitWithCode "POWERSHELL_EXCEPTION_$_" }
}