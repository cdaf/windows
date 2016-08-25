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
if(!$?){ 
	if ( $LASTEXITCODE -eq 0 ) {
		Write-host "[$scriptName] Warning flag set, but exit code is $LASTEXITCODE, proceeding normally." -ForegroundColor Yellow
		& echo "[$scriptName] Reset call operator : ";$?
 	} else {
		throwErrorlevel $LASTEXITCODE
	}
}
exit 0
