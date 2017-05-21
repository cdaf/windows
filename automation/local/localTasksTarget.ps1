
function getProp ($propName) {
	try {
		$propValue=$(& .\getProperty.ps1 $propertiesFile $propName)
		if(!$?){ taskWarning }
	} catch { exceptionExit "LOCAL_TASKS_TARGET_getProp" $_ }
	
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
	    if(!$?){ taskFailure "LOCAL_OVERRIDESCRIPT_TRAP" }
    } catch { exceptionExit "LOCAL_OVERRIDESCRIPT_EXCEPTION" $_ }


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
    & .\execute.ps1 $SOLUTION $BUILD $TARGET $taskList
	if($LASTEXITCODE -ne 0){ passExitCode "LOCAL_TASKS_TARGET_EXECUTE_NON_ZERO_EXIT .\execute.ps1 $SOLUTION $BUILD $TARGET $taskList" $LASTEXITCODE }
    if(!$?){ taskFailure "LOCAL_TASKS_TARGET_EXECUTE_TRAP" }
}
