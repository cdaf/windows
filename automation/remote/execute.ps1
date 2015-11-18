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

function itemRemove ($itemPath) { 
# If item exists, and is not a directory, remove read only and delete, if a directory then just delete
	if ( Test-Path $itemPath ) {
		write-host "[$scriptName] Delete $itemPath"
		Remove-Item $itemPath -Recurse
		if(!$?) {exitWithCode "Remove-Item $itemPath -Recurse" }
	}
}

function copyVerbose ($from, $to) {

	Write-Host "copyVerbose $from --> $to" 
	Copy-Item $from $to -Force
	if(!$?){ taskFailure ("Copy remote script $from --> $to") }
	
}

$SOLUTION    = $args[0]
$BUILDNUMBER = $args[1]
$TARGET      = $args[2]
$TASK_LIST   = $args[3]
$ACTION      = $args[4]

# Set the temporary directory (system wide)
$TMPDIR = [Environment]::GetEnvironmentVariable("TEMP","Machine")

$scriptName = $myInvocation.MyCommand.Name 

Write-Host "~~~~~ Starting Execution Engine ~~~~~~"
Write-Host
Write-Host "[$scriptName]  SOLUTION    : $SOLUTION"
Write-Host "[$scriptName]  BUILDNUMBER : $BUILDNUMBER"
Write-Host "[$scriptName]  TARGET      : $TARGET"
Write-Host "[$scriptName]  TASK_LIST   : $TASK_LIST"
Write-Host "[$scriptName]  ACTION      : $ACTION"
Write-Host "[$scriptName]  TMPDIR      : $TMPDIR"

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

	        # Check for cross platform key words, only if the string is longer enough
	        if ($expression.length -gt 6) {

				# Set a variable, PowerShell format
	            if ( $expression.substring(0,6) -match 'assign' ) {
		            $expression = $expression.Substring(7)
	            }
	
				# Delete (verbose)
	            if ( $expression.substring(0,6) -match 'remove' ) {
		            $expression = "itemRemove " + $expression.Substring(7)
	            }

				# Delete (verbose)
	            if ( $expression.substring(0,6) -match 'vecopy' ) {
		            $expression = "copyVerbose " + $expression.Substring(7)
	            }

				# Invoke a custom script
	            if ( $expression.substring(0,6) -match 'invoke' ) {
	            	$expression = $expression.Substring(7)
	            	$keywordMessageStart = "  ---- Start invoke $expression ---   "
	            	$keywordMessageStop = "  ----- Stop invoke $expression ---   "
	            	$expBuilder = ".\"
		            $pos = $expression.IndexOf(" ")
		            if ( $pos -lt 0 ) {
			            $expression = $expBuilder + $expression + ".ps1"
		            } else {
		            	$expBuilder += $expression.Substring(0, $pos) + ".ps1 "
						$expression = $expBuilder + $expression.Substring($pos+1)
					}
	            }

	        }

	        # Do not echo line if it is an echo itself
            if (-not (($expression -match 'Write-Host') -or ($expression -match 'echo'))) {
	            Write-Host "$expression"
            }

            # Keyword messaging
            if ( $keywordMessageStart ) {
	            write-host
	            Write-Host "[$scriptName] $keywordMessageStart"
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
	        
            # Keyword messaging
            if ( $keywordMessageStop ) {
	            write-host
	            Write-Host "[$scriptName] $keywordMessageStop"
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
Write-Host
Write-Host "~~~~~ Shutdown Execution Engine ~~~~~~"
