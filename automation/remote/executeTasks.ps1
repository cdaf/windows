# Consolidated Error processing function
#  required : error message
#  optional : exit code, if not supplied only error message is written
function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		if ( $exitcode ) {
			Write-Host "`n[$scriptName]$message" -ForegroundColor Red
		} else {
			Write-Host "`n[$scriptName] ERRMSG triggered without message parameter." -ForegroundColor Red
		}
	} else {
		if ( $exitcode ) {
			Write-Warning "`n[$scriptName]$message"
		} else {
			Write-Warning "`n[$scriptName] ERRMSG triggered without message parameter."
		}
	}
	if ( $error ) {
		$i = 0
		foreach ( $item in $Error )
		{
			Write-Host "`$Error[$i] $item"
			$i++
		}
		$Error.clear()
	}
	if ( $exitcode ) {
		if ( $env:CDAF_ERROR_DIAG ) {
			Write-Host "`n[$scriptName] Invoke custom diag `$env:CDAF_ERROR_DIAG = $env:CDAF_ERROR_DIAG`n"
			try {
				Invoke-Expression $env:CDAF_ERROR_DIAG
			    if(!$?) { Write-Host "[CDAF_ERROR_DIAG] `$? = $?" }
			} catch {
				$message = $_.Exception.Message
				$_.Exception | format-list -force
			}
		    if ( $LASTEXITCODE ) {
		    	if ( $LASTEXITCODE -ne 0 ) {
					Write-Host "[CDAF_ERROR_DIAG][EXIT] `$LASTEXITCODE is $LASTEXITCODE"
				}
			}
		}
		Write-Host "`n[$scriptName] Exit with LASTEXITCODE = $exitcode`n" -ForegroundColor Red
		exit $exitcode
	}
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { ERRMSG "[TRAP] `$? = $?" 1211 }
	} catch {
		$message = $_.Exception.Message
		$_.Exception | format-list -force
		$_.Exception.StackTrace
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
			ERRMSG "[EXT][EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[EXT][EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			ERRMSG "[EXT][EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
		} else {
			if ( $error ) {
				ERRMSG "[EXT][WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[EXT][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				ERRMSG "[EXT][WARN] `$LASTEXITCODE not set, but standard error populated"
	    	}
		}
	}
}

# Return named property from TARGET
function getProp ($propName) {

	try {
		$propValue=$(& ${CDAF_CORE}\getProperty.ps1 .\$TARGET $propName)
		if(!$?){ ERRMSG "getProp halted" }
	} catch {
		ERRMSG "getProp threw execption retrieving $propName from .\$TARGET " 4402
	}
	
    return $propValue
}

$TARGET  = $args[0]
$RELEASE = $args[1]
$OPT_ARG = $args[2]

# $myInvocation.MyCommand.Name not working when processing DOS
$scriptName = "executeTasks.ps1"

if ( $TARGET ) {
	$TARGET = Invoke-Expression "Write-Output $TARGET"
	write-host "[$scriptName]   TARGET    : $TARGET"
} else {
	ERRMSG "TARGET not supplied." 4401
}

if ( $RELEASE ) {
	$RELEASE = Invoke-Expression "Write-Output $RELEASE"
    write-host "[$scriptName]   RELEASE   : $RELEASE"
} else {
	if ( $env:RELEASE ) {
		$RELEASE = $env:RELEASE
	    write-host "[$scriptName]   RELEASE   : $RELEASE (from environment variable)"
	} else {
	    write-host "[$scriptName]   RELEASE   : (not supplied)"
	}
}

if ( $OPT_ARG ) {
	$OPT_ARG = Invoke-Expression "Write-Output $OPT_ARG"
    write-host "[$scriptName]   OPT_ARG   : $OPT_ARG"
} else {
	if ( $env:OPT_ARG ) {
		$OPT_ARG = $env:OPT_ARG
	    write-host "[$scriptName]   OPT_ARG   : $OPT_ARG (from environment variable)"
	else
	    write-host "[$scriptName]   OPT_ARG   : (not supplied)"
	}
}

$WORKSPACE = $(Get-Location)
write-host "[$scriptName]   WORKSPACE : $WORKSPACE (pwd)"

$CDAF_CORE = $(pwd)
Write-Host "[$scriptName]   CDAF_CORE : $CDAF_CORE"

write-host "[$scriptName]   hostname  : $(hostname)"
write-host "[$scriptName]   whoami    : $(whoami)"

write-host "`n[$scriptName] Load SOLUTION and BUILDNUMBER from manifest.txt"
& "$CDAF_CORE\Transform.ps1" ".\manifest.txt" | ForEach-Object { invoke-expression $_ }

$scriptOverride = getProp ("deployScriptOverride")
if ($scriptOverride ) {
	write-host "[$scriptName]   deployScriptOverride : $scriptOverride`n"
    executeExpression "& '.\$scriptOverride' '$SOLUTION' '$BUILDNUMBER' '$TARGET' '$OPT_ARG'"

} else {

    $taskOverride = getProp "deployTaskOverride"
    if ($taskOverride ) {
	    $taskList = $taskOverride
    } else {
	    $taskList = "tasksRunRemote.tsk"
    }

	foreach ( $taskItem in $taskList.Split() ) {
	    write-host "`n[$scriptName] --- Executing $taskItem ---`n" -ForegroundColor Green
	    executeExpression "& '$CDAF_CORE\execute.ps1' '$SOLUTION' '$BUILDNUMBER' '$TARGET' '$taskItem' '$OPT_ARG'"
    }
}