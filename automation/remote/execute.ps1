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

$SOLUTION    = $args[0]
$BUILDNUMBER = $args[1]
$TARGET      = $args[2]
$TASK_LIST   = $args[3]
$ACTION      = $args[4]

$scriptName = $myInvocation.MyCommand.Name 

Write-Host "[$scriptName]  SOLUTION    : $SOLUTION"
Write-Host "[$scriptName]  BUILDNUMBER : $BUILDNUMBER"
Write-Host "[$scriptName]  TARGET      : $TARGET"
Write-Host "[$scriptName]  TASK_LIST   : $TASK_LIST"
Write-Host "[$scriptName]  ACTION      : $ACTION"

# If called from build process, automation root will be set
$automationHelper="$AUTOMATIONROOT\remote"

Write-Host

# Initialise termination variable
$terminate = "no"

Foreach ($line in get-content $TASK_LIST) {

    # If the task line is empty, simply log an empty line
    if (-not ($line)) {

	    write-host

    } else {

        # discard all characters after comment marker
        $expression=$line.split("#")
        $expression=$expression[0]

        # Do not attempt any processing when a line is just a comment
        if ($expression) {

	        # Do not echo line if it is an echo itself
            if (-not ($expression -match 'Write-Host')) {
	            Write-Host "$expression"
            }

            # Execute expression and trap powershell exceptions
	        try {
		        Invoke-Expression $expression
		        if(!$?) { taskException "POWERSHELL_TRAP" $_ }
	        } catch { taskException "POWERSHELL_EXCEPTION" $_ }

            # Look for DOS exit codes
	        $exitcode = $LASTEXITCODE
	        if ( $exitcode -gt 0 ) { 
		        Write-Host
		        Write-Host "[$scriptName] $expression failed with LASTEXITCODE = $exitcode" -ForegroundColor Red
		        throwErrorlevel "DOS_TERM" $exitcode
	        }

            # Check for non-terminating errors, any error will terminate execution
	        if ( $error[0] ) { 
		        Write-Host
		        Write-Host "[$scriptName] $expression failed with ERROR[0] = $error[0]" -ForegroundColor Red
		        throwErrorlevel "DOS_NON_TERM" $exitcode
	        }

			# Information message for clean
			If ($terminate -eq "clean") {
		        Write-Host
		        Write-Host "[$scriptName] Clean only" -ForegroundColor Blue
				break
			}

			# Load Properties file as runtime variables
			If ($loadProperties) {
			
				$transform = ".\Transform.ps1"

				# Load all properties as runtime variables (transform provides logging)
				# Test for running as delivery process
				if (!( test-path $transform)) {
				
					# Test for running as a build process
					$transform = "..\$automationHelper\Transform.ps1"
					if (! (test-path $transform)) {
				
						# Test for running as a package parocess
						$transform = "$automationHelper\Transform.ps1"
					}
				}
				
				& $transform "$loadProperties" | ForEach-Object { invoke-expression $_ }
				$loadProperties = ""
			}

        }
    }
} 
