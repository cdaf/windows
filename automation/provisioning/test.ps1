function ExitWithCode { 
    param ($exitcode)
    $host.SetShouldExit($exitCode)
    exit
}

function taskComplete { param ($taskName)
    write-host ""
    write-host "[$scriptName] Remote Task ($taskName) Successfull " -ForegroundColor Green
    write-host ""
}

# Basic Tests for remote powershell
$targetEnv = $args[0]
$scriptName = $myInvocation.MyCommand.Name 

Write-Host "args[0] : $targetEnv"

$currentDirectory = Get-Location 
$localMachine = hostname
$userID = whoami

Write-Host ""
Write-Host "[$scriptName] Running locally as $userID on $localMachine in $currentDirectory, attempting remote execution on $targetEnv (passing pid=$pid)..."

$taskName = "RemoteTest.ps1"
try {
    Invoke-Command -ComputerName $targetEnv -file $taskName -Args $pid
	if(!$?){ $exitStatus = -1}
} catch {
    write-host "[$scriptName] Caught an exception:" -ForegroundColor Red
    write-host "     Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($_.Exception.Message)" -ForegroundColor Red
	$exitStatus = -1
}

if (!$exitStatus) {
    taskComplete -taskName $taskName
} else {
    write-host "[$scriptName] Failed with exitStatus = $exitStatus" -ForegroundColor Red
}

ExitWithCode -exitcode $exitStatus

# Trouble shooting

# Check that "Remote Registry" and "Windows Remote Management (WS-Management)" are running
# Test-WsMan $targetEnv

# Try Configuration tool
# winrm quickconfig

# Not sure if this is actually required, however to set SPN to the following
# REQUIRES DOMAIN ADMIN elevated powershell
# setspn.exe -L $targetEnv
# setspn.exe -A HTTP/$targetEnv $targetEnv
# setspn.exe -A HTTP/$targetEnv.$env:userdnsdomain $targetEnv