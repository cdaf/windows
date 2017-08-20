Add-Type -AssemblyName System.IO.Compression.FileSystem

# Convert exceptions and errors into generic exit code.
function taskException ($taskName, $exception) {
    write-host "[$scriptName (taskException)] Caught an exception excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($exception.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($exception.Exception.Message)" -ForegroundColor Red
	exit -3
}

function MAKDIR ($itemPath) { 
# If directory already exists, just report, otherwise create the directory and report
	if ( Test-Path $itemPath ) {
		if (Test-Path $itemPath -PathType "Container") {
			write-host "[$scriptName (MAKDIR)] $itemPath exists"
		} else {
			Remove-Item $itemPath -Recurse -Force
			if(!$?) { taskFailure "[$scriptName (MAKDIR)] Remove-Item $itemPath -Recurse -Force" }
			mkdir $itemPath > $null
			if(!$?) { taskFailure "[$scriptName (MAKDIR)] (replace) $itemPath Creation failed" }
		}	
	} else {
		mkdir $itemPath > $null
		if(!$?) {taskFailure "[$scriptName (MAKDIR)] $itemPath Creation failed" }
	}
}

function REMOVE ($itemPath) { 
# If item exists, and is not a directory, remove read only and delete, if a directory then just delete
	if ( Test-Path $itemPath ) {
		write-host "[REMOVE] Delete $itemPath"
		Remove-Item $itemPath -Recurse -Force
		if(!$?) {taskFailure "[$scriptName (REMOVE)] Remove-Item $itemPath -Recurse -Force" }
	}
}

# Recursive copy function to behave like cp -vR in linux
function VECOPY ($from, $to, $notFirstRun) {
	try {
	
		if (Test-Path $from -PathType "Container") {
	
			if ( Test-Path $to ) {
			
				# If this is the first call, i.e. at the root of the source and the target exists, and is a folder,
				# recursive copy into a subfolder, else recursive call into root of the target 
				if (Test-Path $to -PathType "Container") {
				
					# Only create a subdirectory if the root exists, otherwise copy into the root
					if (! ($notFirstRun)) {
						$fromLeaf = Split-Path "$from" -Leaf
						$to = "$to\$fromLeaf"
					}
					
				} else {
				
					# The existing path is a file, not a directory, delete the file and replace with a directory
					Remove-Item $to -Recurse -Force
					if(!$?) {taskFailure "[$scriptName (VECOPY)] Remove-Item $to -Recurse -Force" }
					Write-Host "  $from --> $to (replace file with directory)" 
					mkdir $to > $null
					if(!$?) {taskFailure "[$scriptName (VECOPY)] (replace) $to Creation failed" }
				}
			}
			
			# Previous process may have changed the target, so retest and if still not existing, create it	
			if ( ! (Test-Path $to)) {
				Write-Host "  $from --> $to"
				mkdir $to > $null
				if(!$?) {taskFailure "[$scriptName (VECOPY)] $to Creation failed" }
			}
	
			foreach ($child in (Get-ChildItem -Path "$from" -Name )) {
				VECOPY "$from\$child" "$to\$child" $true
			}
			
		} else {
	
			Write-Host "  $from --> $to" 
			Copy-Item $from $to -force -recurse
			if(!$?){ taskFailure ("[$scriptName (VECOPY)] Copy remote script $from --> $to") }
			
		}
	} catch { taskException "VECOPY_TRAP" $_ }
}

# Compress to file (Requires PowerShell v3 or above)
#  required : file, relative to current workspace
#  required : source directory, relative to current workspace
function CMPRSS( $zipfilename, $sourcedir )
{
	$currentDir = $(pwd)
	$zipfilename += '.zip'
	if ($zipfilename -like '*:*') { # Only resolve full path if a full path has not been supplied
		$targetFile = "$zipfilename"
	} else {
		$targetFile = "$currentDir\$zipfilename"
	}
	if (Test-Path "$sourcedir") {
		cd $sourcedir
		$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
		Write-Host "`n[$scriptName] Create zip package $targetFile from $(pwd)"
		[System.IO.Compression.ZipFile]::CreateFromDirectory("$(pwd)", "$targetFile", $compressionLevel, $false)
		cd $currentDir
		foreach ($item in (Get-ChildItem -Path "$sourcedir")) {
			Write-Host "[$scriptName (CMPRSS)]   --> $item"
		}
	} else {
        Write-Host "`n[$scriptName] ZIP_SOURCE_DIR_NOT_FOUND, exit with LASTEXITCODE = 700" -ForegroundColor Red
		exit 700
	}
}

# Decompress from file (Requires PowerShell v3 or above, pass zip file without .zip suffix)
#  required : file, relative to current workspace
function DCMPRS( $packageFile, $packagePath )
{
    if (!( $packagePath )) {
		$packagePath = $pwd
	}
	$currentDir = $(pwd)
	if ($packagePath -eq '.') { $packagePath = $(pwd) }
	Write-Host "`n[$scriptName] Extract zip package $packageFile.zip to $packagePath"
	[System.IO.Compression.ZipFile]::ExtractToDirectory("$currentDir/$packageFile.zip", "$packagePath/$packageFile")
	foreach ($item in (Get-ChildItem -Path $packagePath/$packageFile)) {
		Write-Host "[$scriptName (DCMPRS)]    --> $item"
	}
}

# Replace in file
#  required : file, relative to current workspace
#  required : name, the token to be replaced
#  required : value, the replacement value
function REPLAC( $fileName, $token, $value )
{
	try {
	(Get-Content $fileName | ForEach-Object { $_ -replace "$token", "$value" } ) | Set-Content $fileName
	    if(!$?) { taskException "REPLAC_TRAP" }
	} catch { taskException "REPLAC_TRAP" $_ }
}

# Use the Decryption helper script
function DECRYP( $encryptedFile, $thumbprint, $location )
{
	./decryptKey.ps1 $encryptedFile $thumbprint $location
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
Write-Host

# If called from build process, automation root will be set
$automationHelper="$AUTOMATIONROOT\remote"

# Initialise termination variable
$terminate = "no"

# Load the target properties (although these are global in powershell, load again as a diagnostic tool
$propFile = "$TARGET"
$transform = '.\Transform.ps1'

if ( test-path -path "$TARGET" -pathtype leaf ) {
	if (!( test-path "$transform")) {
	
		# Test for running as a build process
		$transform = "..\$automationHelper\Transform.ps1"
		if (! (test-path $transform)) {
	
			# Assume running as a package parocess
			$transform = "$automationHelper\Transform.ps1"
		}
	}
	try {
		& $transform "$propFile" | ForEach-Object { invoke-expression $_ }
	    if(!$?) { taskException "PRODLD_TRAP" }
	} catch { taskException "PRODLD_EXCEPTION" $_ }
	Write-Host
}	

if (!( Test-Path $TASK_LIST )) {
    Write-Host "`n[$scriptName] Task Execution file ($TASK_LIST) not found! `$LASTEXITCODE 9998" -ForegroundColor Red
    exit 9998
}
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

				# Check for cross platform key words, first 6 characters, by convention uppercase but either supported
				$feature=$expression.substring(0,7).ToUpper()

				# Exit (normally) if argument set
	            if ( $feature -eq 'EXITIF ' ) {
		            $exitVar = $expression.Substring(7)
		            Write-Host "$expression ==> if ( $exitVar ) then exit" -NoNewline
		            $expression = "if ( $exitVar ) { Write-Host `", controlled exit due to `$exitVar = $exitVar`"; exit }"
	            }
					
				# Load Properties from file as variables
	            if ( $feature -eq 'PROPLD ' ) {
		            $propFile = $ExecutionContext.InvokeCommand.ExpandString($expression.Substring(7))
					$transform = ".\Transform.ps1"
	
					# Load all properties as runtime variables (transform provides logging)
					# Test for running as delivery process
					if (!( test-path $transform)) {
					
						# Test for running as a build process
						$transform = "..\$automationHelper\Transform.ps1"
						if (! (test-path $transform)) {
					
							# Assume running as a package parocess
							$transform = "$automationHelper\Transform.ps1"
						}
					}
		            Write-Host "$expression ==> $transform $propFile" -NoNewline
					Write-Host
			        try {
						& $transform "$propFile" | ForEach-Object { invoke-expression $_ }
				        if(!$?) { taskException "PRODLD_TRAP" }
			        } catch { taskException "PRODLD_EXCEPTION" $_ }
	            }

				# Set a variable, PowerShell format
	            if ( $feature -eq 'ASSIGN ' ) {
		            Write-Host "$expression ==> " -NoNewline
		            $expression = $expression.Substring(7)
	            }

				# Decrypt a file
				#  required : file location
				#  optional : thumbprint, if decrypting using certificate
	            if ( $feature -eq 'DECRYP ' ) {
		            Write-Host "$expression ==> " -NoNewline
		            $arguments = $expression.Substring(7)
					$expression = "`$RESULT = DECRYP $arguments"
				}

				# Invoke a custom script
	            if ( $feature -eq 'INVOKE ' ) {
		            Write-Host "$expression ==> " -NoNewline
	            	$expression = $expression.Substring(7)
	            	$expBuilder = ".\"
		            $pos = $expression.IndexOf(" ")
		            if ( $pos -lt 0 ) {
			            $expression = $expBuilder + $expression + ".ps1"
		            } else {
		            	$expBuilder += $expression.Substring(0, $pos) + ".ps1 "
						$expression = $expBuilder + $expression.Substring($pos+1)
					}
	            }
	            
				# Push file to remote system
	            if ( $feature -eq 'EXPUSH ' ) {
	            	if ($remoteUser ) {
	            		$remUser = $remoteUser 
	            	} else {
		            	$remUser = 'NOT_SUPPLIED'
	            	}
	            	if ($remoteCred ) {
	            		$remCred = $remoteCred 
	            	} else {
		            	$remCred = 'NOT_SUPPLIED'
	            	}
	            	if ($decryptThb ) {
	            		$remThumb = $decryptThb 
	            	} else {
		            	$remThumb = 'NOT_SUPPLIED'
	            	}
		            Write-Host "$expression ==> " -NoNewline
	            	$expression = '.\remoteExec.ps1 ' + $deployHost + ' ' + $remUser  + ' ' + $remCred + ' ' + $remThumb  + ' ' + $expression.Substring(7)
	            }

				# Execute Remote Command or Local PowerShell Script remotely (via Invoke-Command)
	            if ( $feature -eq 'EXCREM ' ) {
	            	if ($remoteUser ) {
	            		$remUser = $remoteUser 
	            	} else {
		            	$remUser = 'NOT_SUPPLIED'
	            	}
	            	if ($remoteCred ) {
	            		$remCred = $remoteCred 
	            	} else {
		            	$remCred = 'NOT_SUPPLIED'
	            	}
	            	if ($decryptThb ) {
	            		$remThumb = $decryptThb 
	            	} else {
		            	$remThumb = 'NOT_SUPPLIED'
	            	}
		            Write-Host "$expression ==> " -NoNewline
	            	$expression = '.\remoteExec.ps1 ' + $deployHost + ' ' + $remUser  + ' ' + $remCred + ' ' + $remThumb  + ' ' + $expression.Substring(7)
	            }

				# Detokenise a file
				#  required : tokenised file, relative to current workspace
				#  option : properties file, if not passed, target will be used
	            if ( $feature -eq 'DETOKN ' ) {
		            Write-Host "$expression ==> " -NoNewline
	            	$arguments = $expression.Substring(7)
					$data = $arguments.split(" ")
					$tokenFile = $data[0]
					$properties = $data[1]
	            	$expression = ".\Transform.ps1 "
		            if ($properties) {
			            $expression += $properties + " " + $tokenFile
		            } else {
		            	$expression += $TARGET + " " + $tokenFile
					}
	            }
	        }

			# Perform no further processing if Feature is Property Loader
            if ( $feature -ne 'PROPLD ' ) {
			
		        # Do not echo line if it is an echo itself
	            if (-not (($expression -match 'Write-Host') -or ($expression -match 'echo'))) {
		            Write-Host "$expression"
	            }
	
	            # Execute expression and trap powershell exceptions
		        try {
			        Invoke-Expression $expression
			        if(!$?) { taskException "POWERSHELL_TRAP" $_ }
		        } catch { taskException "POWERSHELL_EXCEPTION" $_ }
	
	            # Look for DOS exit codes
		        $exitcode = $LASTEXITCODE
		        if ( $exitcode -ne 0 ) { 
			        Write-Host "`n[$scriptName] $expression failed with `$LASTEXITCODE $exitcode" -ForegroundColor Red
			        exit $exitcode
		        }
	
	            # Check for non-terminating errors, any error will terminate execution
		        if ( $error[0] ) { 
			        Write-Host "`n[$scriptName] $expression failed with ERROR[0] = $error[0], exit with LASTEXITCODE 9999" -ForegroundColor Red
			        exit 9999
		        }
		    }
        }
    }
}
Write-Host
Write-Host "~~~~~ Shutdown Execution Engine ~~~~~~"
