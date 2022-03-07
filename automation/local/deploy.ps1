Param (
	[string]$TARGET,
	[string]$WORKSPACE,
	[string]$warnondeployerror,
	[string]$OPT_ARG
)

function throwErrorlevel ($trappedExit) {
    write-host "[$scriptName] Trapped DOS exit code $trappedExit, throwing as exception`n" -ForegroundColor Red
    throw "$trappedExit"
}

# Dummy script to transition from remote powershell to local power shell via DOS batch execution override
$scriptName = "deploy.ps1"

write-host "[$scriptName] cd $WORKSPACE"
Set-Location $WORKSPACE
write-host
& .\deploy.bat $TARGET $ENVIRONMENT $OPT_ARG
if ( !$? ) {
	$exitCode = $LASTEXITCODE
	if ( $exitCode -ne 0 ) {
		if ( $warnondeployerror ) {
			Write-host "[$scriptName] deploy.bat did not complete normally, however `$warnondeployerror set ($warnondeployerror) so proceeding normally." -ForegroundColor Yellow
			cmd /c "exit 0"
			& Write-Output "[$scriptName] Reset call operator : ";$?
		} else {
			throwErrorlevel $exitCode
		}
	} else {
		Write-host "[$scriptName][WARN] `$LASTEXITCODE = $LASTEXITCODE`n  `$Error[] = $Error`n" -ForegroundColor Yellow
		$Error.clear()
		Write-host "[$scriptName] Exit normally ..." -ForegroundColor Yellow
	}
}
exit 0
