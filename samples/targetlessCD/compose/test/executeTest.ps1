Param (
	[string]$ENVIRONMENT
)

# Initialise
cmd /c "exit 0"
$scriptName = 'executeTest.ps1'

# Customised Error Hander to keep container alive, even if test fails.
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
#		exit $exitcode
		$script:test_failure = 'yes'
	}
}

# Customised Expression Executor to log success message if no errors handled.
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
			ERRMSG "[EXEC][EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[EXEC][EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			ERRMSG "[EXEC][EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
		} else {
			if ( $error ) {
				ERRMSG "[EXEC][WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[EXEC][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				ERRMSG "[EXEC][WARN] `$LASTEXITCODE not set, but standard error populated"
	    	}
		}
	}
	if ( $script:test_failure ) {
		Write-Host "`n[$scriptName] CDAF_DELIVERY_FAILURE"
	} else {
		Write-Host "`n[$scriptName] Automated Test Execution completed successfully."
	}
}

Write-Host "`n[$scriptName] ---------- start ----------`n"
if ($ENVIRONMENT) {
    Write-Host "[$scriptName] ENVIRONMENT : $ENVIRONMENT"
} else {
    Write-Host "[$scriptName] ENVIRONMENT : (not supplied)" 
}

Write-Host "`n[$scriptName] Execute CDAF Delivery`n"
executeExpression ".\TasksLocal\delivery.bat $ENVIRONMENT"

Write-Host "`n[$scriptName] ---------- Watch System Events to keep container alive ----------"

$idx = (get-eventlog -LogName System -Newest 1).Index

while ($true) {
	start-sleep -Seconds 1
	$idx2  = (Get-EventLog -LogName System -newest 1).index
	get-eventlog -logname system -newest ($idx2 - $idx) |  Sort-Object index
	$idx = $idx2
}
