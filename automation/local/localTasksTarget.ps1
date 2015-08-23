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

write-host "[$scriptName] -----------------"
write-host "[$scriptName]   Local Execute"
write-host "[$scriptName] -----------------"
write-host "[$scriptName] propertiesFile : $propertiesFile"

$overrideTask = getProp ("deployScriptOverride")
if ($overrideTask ) {
	$taskList = $overrideTask
	write-host "[$scriptName]   taskList     : $taskList (based on deployScriptOverride in properties file)"
} else {
	$taskList = "tasksRunLocal.tsk"
	write-host "[$scriptName]   taskList     : $taskList (default, deployScriptOverride not found in properties file)"
}

Write-Host
# Execute the Tasks Driver File
try {
	& .\execute.ps1 $SOLUTION $BUILD $TARGET $taskList
	if(!$?){ taskException "POWERSHELL_TRAP" $_ }
} catch { taskException "POWERSHELL_EXCEPTION" $_ }

