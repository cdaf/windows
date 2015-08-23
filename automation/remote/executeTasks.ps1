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
		$propValue=$(& .\getProperty.ps1 ..\$TARGET $propName)
		if(!$?){ taskWarning }
	} catch { exitWithCode "getProp" }
	
    return $propValue
}

$TARGET    = $args[0]
$WORKSPACE = $args[1]

# $myInvocation.MyCommand.Name not working when processing DOS
$scriptName = "executeTasks.ps1"

write-host "[$scriptName]   TARGET    : $TARGET"
write-host "[$scriptName]   WORKSPACE : $WORKSPACE"

$overrideTask = getProp "deployScriptOverride"
if ($overrideTask ) {
	$taskList = $overrideTask
} else {
	$taskList = "tasksRunRemote.tsk"
}

if ($overrideTask) {
	write-host "[$scriptName]   taskList  : $taskList (based on deployScriptOverride in properties file)"
} else {
	write-host "[$scriptName]   taskList  : $taskList"
}
write-host
write-host "[$scriptName] Load solution properties from manifest.txt"
& .\Transform.ps1 "..\manifest.txt" | ForEach-Object { invoke-expression $_ }

Write-Host
write-host "[$scriptName] Execute the Tasks defined in $taskList"
Write-Host
try {
	& .\execute.ps1 $SOLUTION $BUILDNUMBER $TARGET $taskList
	if(!$?){ exitWithCode "POWERSHELL_TRAP_$_" }
} catch { exitWithCode "POWERSHELL_EXCEPTION_$_" }
