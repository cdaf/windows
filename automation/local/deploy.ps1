function throwErrorlevel ($trappedExit) {
    write-host "[$scriptName] Trapped DOS exit code $trappedExit, throwing as exception" -ForegroundColor Red
	write-host
    throw "DOS $trappedExit"
}

$TARGET      = $args[0]
$WORKSPACE   = $args[1]

# $myInvocation.MyCommand.Name not working when processing DOS
$scriptName = "deploy.ps1"

# Dummy script to transition from remote powershell to local power shell via DOS batch execution override
write-host "[$scriptName] cd $WORKSPACE"
cd $WORKSPACE
write-host
& .\deploy.bat $TARGET $ENVIRONMENT
if(!$?){ throwErrorlevel $LASTEXITCODE }