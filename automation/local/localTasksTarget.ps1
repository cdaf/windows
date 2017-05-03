function taskException ($taskName, $invokeException) {
    write-host "[$scriptName] Caught an exception excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($invokeException.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($invokeException.Exception.Message)" -ForegroundColor Red
	write-host
    throw "$taskName HALT"
}

function taskWarning { 
    write-host "[$scriptName] Warning, $taskName encountered an error that was allowed to proceed." -ForegroundColor Yellow
}

function getProp ($propName) {
	try {
		$propValue=$(& .\getProperty.ps1 $propertiesFile $propName)
		if(!$?){ taskWarning }
	} catch { taskException("getProp") }
	
    return $propValue
}

$ENVIRONMENT      = $args[0]
$SOLUTION         = $args[1]
$BUILD            = $args[2]
$TARGET           = $args[3]

$scriptName = $myInvocation.MyCommand.Name 
$propertiesFile = "propertiesForLocalTasks\$TARGET"

write-host
write-host "[$scriptName]   propertiesFile       : $propertiesFile"

$scriptOverride = getProp ("deployScriptOverride")
if ($scriptOverride ) {
	$taskList = $scriptOverride
	write-host "[$scriptName]   deployScriptOverride : $scriptOverride"
    Write-Host
    $expression=".\$scriptOverride $SOLUTION $BUILD $TARGET"
    write-host $expression
	try {
		Invoke-Expression $expression
	    if(!$?){ taskException "LOCAL_OVERRIDESCRIPT_TRAP" $_ }
    } catch { taskException "LOCAL_OVERRIDESCRIPT_EXCEPTION" $_ }


} else {

    $taskOverride = getProp ("deployTaskOverride")
    if ($taskOverride ) {
	    $taskList = $taskOverride
	    write-host "[$scriptName]   taskOverride         : $taskOverride"
    } else {
	    $taskList = "tasksRunLocal.tsk"
	    write-host "[$scriptName]   taskOverride         : $taskList (default, deployTaskOverride not found in properties file)"
    }

    Write-Host
    # Execute the Tasks Driver File
    try {
	    & .\execute.ps1 $SOLUTION $BUILD $TARGET $taskList
	    if(!$?){ taskException "EXECUTE_TRAP" $_ }
    } catch { taskException "EXECUTE_EXCEPTION" $_ }
}
