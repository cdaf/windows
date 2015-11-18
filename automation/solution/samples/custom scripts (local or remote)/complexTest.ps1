function taskException ($taskName, $exception) {
    write-host "[$scriptName] Caught an exception excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($exception.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($exception.Exception.Message)" -ForegroundColor Red

	If ($REVISION -eq "remote") {
		write-host
		write-host "[$scriptName] Called from DOS, returning errorlevel -1" -ForegroundColor Blue
		$host.SetShouldExit(-1)
	} else {
		write-host
		write-host "[$scriptName] Called from PowerShell, throwing error" -ForegroundColor Blue
		throw "$taskName $trappedExit"
	}
}

function throwErrorlevel ($taskName, $trappedExit) {
    write-host "[$scriptName] Trapped DOS exit code : $trappedExit" -ForegroundColor Red

	If ($REVISION -eq "remote") {
		write-host
		write-host "[$scriptName] Called from DOS, returning exit code as errorlevel" -ForegroundColor Blue
		$host.SetShouldExit($trappedExit)
	} else {
		write-host
		write-host "[$scriptName] Called from PowerShell, throwing error" -ForegroundColor Blue
		throw "$taskName $trappedExit"
	}
}

# These are the only arguments supported for deployScriptOverride property
$SOLUTION    = $args[0]
$BUILDNUMBER = $args[1]
$TARGET      = $args[2]

$scriptName = $myInvocation.MyCommand.Name 

Write-Host
Write-Host "--- Start Custom Complex Test Example ---"
Write-Host
Write-Host "[$scriptName]  SOLUTION    : $SOLUTION"
Write-Host "[$scriptName]  BUILDNUMBER : $BUILDNUMBER"
Write-Host "[$scriptName]  TARGET      : $TARGET"

$transform = ".\Transform.ps1"
& $transform "$TARGET" | ForEach-Object { invoke-expression $_ }
$loadProperties = ""

Write-Host
Write-Host "--- Stop Custom Complex Test Example ---"
