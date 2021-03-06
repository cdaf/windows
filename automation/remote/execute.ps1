Add-Type -AssemblyName System.IO.Compression.FileSystem

cmd /c "exit 0"
$Error.clear()

function taskException ($taskName, $exception) {
    write-host "[$scriptName (taskException)] Caught an exception excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($exception.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($exception.Exception.Message)" -ForegroundColor Red
	exit 9991
}


# Consolidated Error processing function
function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Red
	} else {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Yellow
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
	if ( $env:CDAF_ERROR_DIAG ) {
		Write-Host "`n[$scriptName] Invoke custom diag `$env:CDAF_ERROR_DIAG = $env:CDAF_ERROR_DIAG`n"
		Invoke-Expression $env:CDAF_ERROR_DIAG
	}
	if ( $exitcode ) {
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
			ERRMSG "[EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			ERRMSG "[EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
		} else {
			if ( $error ) {
				ERRMSG "[WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				ERRMSG "[WARN] `$LASTEXITCODE not set, but standard error populated"
	    	}
		}
	}
}

function MAKDIR ($itemPath) { 
	# If directory already exists, just report, otherwise create the directory and report
	if ( Test-Path $itemPath ) {
		if (Test-Path $itemPath -PathType "Container") {
			write-host "[$scriptName (MAKDIR)] $itemPath exists"
		} else {
			Remove-Item $itemPath -Recurse -Force
			if(!$?) { taskFailure "[$scriptName (MAKDIR)] Remove-Item $itemPath -Recurse -Force" 10002 }
			New-Item $itemPath -ItemType Directory > $null
			if(!$?) { taskFailure "[$scriptName (MAKDIR)] (replace) $itemPath Creation failed" 10003 }
		}	
	} else {
		New-Item $itemPath -ItemType Directory > $null
		if(!$?) { taskFailure "[$scriptName (MAKDIR)] $itemPath Creation failed" 10005 }
	}
}

function REMOVE ($itemPath) { 
	if ( Test-Path $itemPath ) {
		write-host "[REMOVE] Remove-Item $itemPath -Recurse -Force"
		Remove-Item $itemPath -Recurse -Force
		if(!$?) { taskFailure "[$scriptName (REMOVE)] Remove-Item $itemPath -Recurse -Force" 10006 }
	}
}

# Recursive copy function to behave like cp -vR in linux
function VECOPY ($from, $to, $notFirstRun) {
	try {
		if ( Test-Path $from ) {

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
						if(!$?) { ERRMSG "[REPLACE_FILE_WITH_DIR] Unable to remove existing file $to to replace with directory!" 10007 }
						Write-Host "  $from --> $to (replace file with directory)" 
						New-Item $to -ItemType Directory > $null
						if(!$?) { ERRMSG "[REPLACE_DIR_HALT] $to Creation failed" 10008 }
					}
				}

				# Previous process may have changed the target, so retest and if still not existing, create it	
				if ( ! (Test-Path $to)) {
					Write-Host "  $from --> $to"
					New-Item $to -ItemType Directory > $null
					if(!$?) { ERRMSG "[MAKE_DIR_HALT] $to Creation failed" 10009 }
				}

				foreach ($child in (Get-ChildItem -Path "$from" -Name )) {
					VECOPY "$from\$child" "$to\$child" $true
				}

			} else {

				$toParent = Split-Path $to
				if (( $toParent ) -and ( ! (Test-Path $toParent))) { # do not try to create directory is $to is root (c:\) or current directory (.)
					New-Item $toParent -ItemType Directory > $null
				}

				if ( Test-Path $to ) {
					if ( (Get-Item $from).FullName -eq (Get-Item $to).FullName ) {
						Write-Host "  $from --> $to are the same, do not attempt to copy file over itself" 
					} else {
						Write-Host "  $from --> $to (replace)" 
						Copy-Item $from $to -force -recurse
						if(!$?){ ERRMSG "[COPY_REPLACE_HALT] Copy remote script $from --> $to" 10010 }
					}
				} else {
					Write-Host "  $from --> $to"
					Copy-Item $from $to -force -recurse
					if(!$?){ ERRMSG "[COPY_HALT] Copy remote script $from --> $to" 10010 }
				}

			}
		} else {
			ERRMSG "[VECOPY_SOURCE_NOT_FOUND] $from" 100011
		}
	} catch { ERRMSG "[VECOPY_TRAP] $($_.Exception.Message)" 100012 }
}

# Refresh Directory, function arguments differ depending on number passed
function REFRSH ( $arg1, $arg2 )
{
	if ( $arg2 ) {
		$destination = $arg2
		$source = $arg1
	} else {
		$destination = $arg1
	}

	# Ensure the destination exists and is empty
	MAKDIR $destination
	Remove-Item "$destination/*" -Recurse -Force
	if ( $source ) {
		if ( Test-Path -Path $source -PathType Container ) {
			VECOPY "$source/*" $destination
		} else {
			VECOPY $source $destination
		}
	}
}

# Compress to file (Requires PowerShell v3 or above)
#  required : file, relative to current workspace
#  required : source directory, relative to current workspace
function CMPRSS ( $zipfilename, $sourcedir )
{
	$currentDir = $(Get-Location)
	if (!( $sourcedir )) {
		$sourcedir = $zipfilename
	}
	$zipfilename += '.zip'
	if ($zipfilename -like '*:*') { # Only resolve full path if a full path has not been supplied
		$targetFile = "$zipfilename"
	} else {
		$targetFile = "$currentDir\$zipfilename"
	}
	if (Test-Path "$sourcedir") {
		Set-Location $sourcedir
		$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
		Write-Host "`n[$scriptName] Create zip package $targetFile from $(Get-Location)"
		[System.IO.Compression.ZipFile]::CreateFromDirectory("$(Get-Location)", "$targetFile", $compressionLevel, $false)
		Set-Location $currentDir
		foreach ($item in (Get-ChildItem -Path "$sourcedir")) {
			Write-Host "[$scriptName (CMPRSS)]   --> $item"
		}
	} else {
        Write-Host "`n[$scriptName] ZIP_SOURCE_DIR_NOT_FOUND, exit with LASTEXITCODE = 700" -ForegroundColor Red
		exit 9995
	}
}

# Decompress from file (Requires PowerShell v3 or above, pass zip file without .zip suffix)
#  required : file, relative to current workspace
function DCMPRS ( $packageFile, $packagePath )
{
    if (!( $packagePath )) {
		$packagePath = $pwd
	}
	$currentDir = $(Get-Location)
	if ($packagePath -eq '.') { $packagePath = $(Get-Location) }
	Write-Host "`n[$scriptName] Extract zip package $packageFile.zip to $packagePath"
	[System.IO.Compression.ZipFile]::ExtractToDirectory("$currentDir/$packageFile.zip", "$packagePath/$packageFile")
	foreach ($item in (Get-ChildItem -Path $packagePath/$packageFile)) {
		Write-Host "[$scriptName (DCMPRS)]    --> $item"
	}
}

# Replace in file
#  required : file name relative to current workspace
#  required : the token to be replaced or an array of name/value pairs
#  optional : the replacement value (not passed if name is array)
function REPLAC ( $fileName, $tokenOrArray, $value )
{
	if (!( Test-Path $fileName )) {
		ERRMSG "REPLAC_FILE_NOT_FOUND $fileName" 1214
	}
	try {
		(Get-Content $fileName | ForEach-Object { $_ -replace [regex]::Escape($tokenOrArray), "$value" } ) | Set-Content $fileName
	    if(!$?) { taskException "REPLAC_EXIT" }
	} catch {
		Write-Host "`n[$scriptName] Exception occured in REPLAC( $fileName, $tokenOrArray, $value )`n" -ForegroundColor Red
		taskException "REPLAC_TRAP" $_
	}
}

# Use the Decryption helper script
function DECRYP ( $encryptedFile, $thumbprint, $location )
{
	./decryptKey.ps1 $encryptedFile $thumbprint $location
}

# Use the the transofrm helper script to perform detokenisation
#  required : tokenised file, relative to current workspace
#  option : properties file, if not passed, target will be used
function DETOKN ( $tokenFile, $properties, $aeskey )
{
    if ($properties) {
    	if ( $aeskey ) {
	        $expression = ".\Transform.ps1 '$properties' '$tokenFile' `$aeskey"
        } else {
	        $expression = ".\Transform.ps1 '$properties' '$tokenFile'"
        }
    } else {
    	if ( $aeskey ) {
	        $expression = ".\Transform.ps1 '$TARGET' '$tokenFile' `$aeskey"
	    } else {
	        $expression = ".\Transform.ps1 '$TARGET' '$tokenFile'"
	    }
	}
	executeExpression $expression
}

# Execute expression, log errors but ignore and proceed
function IGNORE ($expression) {
	if ( $expression ) {
		Write-Host "[$(Get-Date)] $expression"
		try {
			Invoke-Expression "$expression"
			if(!$?) {
				ERRMSG "[IGNORE][ERROR] `$? = $?"
			}
		} catch {
			$_.Exception | format-list -force
			$_.Exception.StackTrace
			ERRMSG "[IGNORE][EXCEPTION] $_.Exception"
		}
		if ( $LASTEXITCODE ) {
			if ( $LASTEXITCODE -ne 0 ) {
				ERRMSG "[IGNORE][LASTEXITCODE] `$LASTEXITCODE = $LASTEXITCODE`n"
				cmd /c "exit 0"
			}
		}
		if ( $error ) {
			ERRMSG "[IGNORE][WARN] `$Error[] = $Error"
		}
	}
}

# Run command elevated (as inbuit NT SYSTEM account)
function ELEVAT ($command) {
    $scriptBlock = [scriptblock]::Create($command)
    configuration elevated {
		Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
        Set-StrictMode -Off
        Node localhost {
            Script execute {
                SetScript = $scriptBlock
                TestScript = {
					if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
						Write-Verbose "Verified Elevated Session"
						return $false
					} else {
						Write-Verbose "Not an Elevated Session!"
						exit 9996
					}
				}
                GetScript = { return @{ 'Result' = 'RUN' } }
            }
        }
    }
    $mof = elevated
	Start-DscConfiguration ./elevated -Wait -Verbose -Force
	if ( $error ) { Write-Host "[ELEVAT][WARN] `$Error[] = $Error" ; $Error.clear() }
}

# Requires vswhere
function MSTOOL ($command) { 
	if ( Test-Path ".\msTools.ps1" ) {
		executeExpression ".\msTools.ps1"
	} else {
		executeExpression "$automationHelper\msTools.ps1"
	}
}

function CMDTST ($command) {
	$oldPreference = $ErrorActionPreference
	$ErrorActionPreference = 'SilentlyContinue'
	try {
		if ( Get-Command $command ) { return $true }
	} catch {
		return $false
	} finally {
		$ErrorActionPreference = $oldPreference
	}
}

function IMGTXT ($imageFile, $palette) {
	Add-Type -AssemblyName system.drawing
	if (!($palette)) { $palette = "shade" } # choose a palette, "ascii" or "shade" 
	$ratio = 1.5        # 1.5 means char height is 1.5 x width
	if ( Test-Path $imageFile ) {
		$imageFile = $(Get-Item background.jng).FullName
	} else {
		Write-Host "imageToText imageFile $imageFile not found! Exit with 9997."
		exit 9997
	}
	$palettes = @{ 
		"ascii" = " .,:;=|iI+hHOE#`$" 
		"shade" = " " + [char]0x2591 + [char]0x2592 + [char]0x2593 + [char]0x2588 
		"bw"    = " " + [char]0x2588 
	  } 
	  $c = $palettes[$palette] 
	  if (-not $c) { 
		write-warning "palette should be one of:  $($palettes.keys.GetEnumerator())" 
		write-warning "defaulting to ascii" 
		$c = $palettes.ascii 
	  } 
	  [char[]]$charpalette = $c.ToCharArray() 
	   
	  $image = [Drawing.Image]::FromFile($imageFile) 
	  if ($maxwidth -le 0) { [int]$maxwidth = $host.ui.rawui.WindowSize.Width - 1} 
	  [int]$imgwidth = $image.Width 
	  [int]$maxheight = $image.Height / ($imgwidth / $maxwidth) / $ratio 
	  $bitmap = new-object Drawing.Bitmap ($image,$maxwidth,$maxheight) 
	  [int]$bwidth = $bitmap.Width; [int]$bheight = $bitmap.Height 
	  # draw it! 
	  $cplen = $charpalette.count 
	  for ([int]$y=0; $y -lt $bheight; $y++) { 
		$line = "" 
		for ([int]$x=0; $x -lt $bwidth; $x++) { 
		  $colour = $bitmap.GetPixel($x,$y) 
		  $bright = $colour.GetBrightness() 
		  [int]$offset = [Math]::Floor($bright*$cplen) 
		  $ch = $charpalette[$offset] 
		  if (-not $ch) { $ch = $charpalette[-1] } #overflow 
		  $line += $ch 
		} 
		$line 
	  } 
}

function MD5MSK ($value) {
	(Get-FileHash -InputStream $([IO.MemoryStream]::new([byte[]][char[]]$value)) -Algorithm MD5).Hash
}

$SOLUTION    = $args[0]
$BUILDNUMBER = $args[1]
$TARGET      = $args[2]
$TASK_LIST   = $args[3]
$ACTION      = $args[4]

$scriptName = $myInvocation.MyCommand.Name 

Write-Host "~~~~~ Starting Execution Engine ~~~~~~`n"
Write-Host "[$scriptName]  SOLUTION    : $SOLUTION"
Write-Host "[$scriptName]  BUILDNUMBER : $BUILDNUMBER"
Write-Host "[$scriptName]  TARGET      : $TARGET"
Write-Host "[$scriptName]  TASK_LIST   : $TASK_LIST"
Write-Host "[$scriptName]  ACTION      : $ACTION"

$TMPDIR = [Environment]::GetEnvironmentVariable("TEMP","Machine")
Write-Host "[$scriptName]  TMPDIR      : $TMPDIR"

$WORKSPACE = (Get-Location).Path
Write-Host "[$scriptName]  WORKSPACE   : $WORKSPACE"

if ( $PROJECT ) {
	Write-Host "[$scriptName]  PROJECT     : $PROJECT"
}
Write-Host

# If called from build process, automation root will be set
$automationHelper = "$AUTOMATIONROOT\remote"

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
	    if(!$?) { taskException "TARGET_LOAD_TRAP" }
	} catch { taskException "TARGET_LOAD_EXCEPTION" $_ }
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
		            $expression = "if ( $exitVar ) { Write-Host `"`n`n~~~~~ controlled exit due to criteria met ~~~~~~`"; exit 0}" }
					
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
				        if(!$?) { taskException "PROPLD_TRAP" }
			        } catch { taskException "PROPLD_EXCEPTION" $_ }
	            }

				# Set a variable, PowerShell format
	            if ( $feature -eq 'ASSIGN ' ) {
		            Write-Host "$expression ==> " -NoNewline
		            $expression = $expression.Substring(7)
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
	        }

			# Perform no further processing if Feature is Property Loader
            if ( $feature -ne 'PROPLD ' ) {
            	
			    # Do not echo line if it is an echo itself
			    if (-not (($expression -match 'Write-Host') -or ($expression -match 'echo'))) {
# This leaks secrets, but I have left it should someone need to temporarilty use it for debugging			    
#			    	$escapeAssign = $expression -replace '^\$', '`$'
#					$ExecutionContext.InvokeCommand.ExpandString($escapeAssign)
					Write-Host "[$(Get-Date)] $expression"
			    }

	            # Execute expression and trap powershell exceptions, do not use executeExpression function of variables will go out of scope
            	$Error.clear()
				try {
					Invoke-Expression "$expression"
					if(!$?) { ERRMSG "[TRAP] `$? = $?" 1211 }
				} catch {
					$message = $_.Exception.Message
					$_.Exception | format-list -force
					$_.Exception.StackTrace
					if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
						ERRMSG "[EXCEPTION] $message" $LASTEXITCODE
					} else {
						ERRMSG "[EXCEPTION] $message" 1212
					}
				}
				if ( $LASTEXITCODE ) {
					if ( $LASTEXITCODE -ne 0 ) {
						ERRMSG "[EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
					} else {
						if ( $error ) {
							ERRMSG "[WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
						}
					} 
				} else {
					if ( $error ) {
						if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
							ERRMSG "[ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
						} else {
							ERRMSG "[WARN] `$LASTEXITCODE not set, but standard error populated"
						}
					}
				}
		    }
        }
    }
}

Write-Host "`n~~~~~ Shutdown Execution Engine ~~~~~~"
exit 0