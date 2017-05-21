# Entry Point for Build Process, child scripts inherit the functions of parent scripts, so these definitions are global for the CI process

function exitWithCode ($exception) {
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
    $host.SetShouldExit(510); exit
}

function taskWarning { 
    write-host "[$scriptName] Warning, $taskName encountered an error that was allowed to proceed." -ForegroundColor Yellow
}

function getProp ($propName) {

	try {
		$propValue=$(& .\getProperty.ps1 .\$TARGET $propName)
		if(!$?){ taskWarning }
	} catch { exitWithCode $_ }
	
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
		if($LASTEXITCODE -ne 0){
		    write-host "[$scriptName] OVERRIDE_EXECUTE_NON_ZERO_EXIT Invoke-Expression $expression" -ForegroundColor Magenta
		    write-host "[$scriptName]   `$host.SetShouldExit($LASTEXITCODE)" -ForegroundColor Red
		    $host.SetShouldExit($LASTEXITCODE); exit
		}
	    if(!$?){ taskFailure "REMOTE_OVERRIDESCRIPT_TRAP" }
    } catch { exitWithCode $_ }

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
    & .\execute.ps1 $SOLUTION $BUILDNUMBER $TARGET $taskList
	if($LASTEXITCODE -ne 0){
	    write-host "[$scriptName] DEPLOY_EXECUTE_NON_ZERO_EXIT & .\execute.ps1 $SOLUTION $BUILDNUMBER $TARGET $taskList" -ForegroundColor Magenta
	    write-host "[$scriptName]   `$host.SetShouldExit($LASTEXITCODE)" -ForegroundColor Red
	    $host.SetShouldExit($LASTEXITCODE); exit
	}
    if(!$?){ taskFailure "POWERSHELL_TRAP" }
}