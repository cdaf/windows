# Generic argument loading because propfile maybe a string or an array
$PROPFILE   = $args[0]
$TOKENFILE  = $args[1]
$aeskey     = $args[2]

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

# 2.5.2 Return SHA256 as uppercase Hexadecimal, default algorith is SHA256, but setting explicitely should this change in the future
function MASKED ($value) {
	(Get-FileHash -InputStream $([IO.MemoryStream]::new([byte[]][char[]]$value)) -Algorithm SHA256).Hash
}

# 2.5.1 Expand variables within variables, value not passed as argument or strings with commas are automatically coverted to arrays
# 2.6.5 Support for strings containing commas
# 2.6.7 Support for strings containing integers
function resolveContent () {
	if ( $value ) {
		[String]$forceToString = invoke-expression "Write-Output $($value.Replace(',', '•').trim())"
		if ( $forceToString ) { $forceToString = invoke-expression "Write-Output $($forceToString.Replace(',', '•').trim())" }
		if ( $forceToString ) { $forceToString = $forceToString.Replace('•', ',') }
		return $forceToString
	} else {
		return
	}
}

$scriptName = $myInvocation.MyCommand.Name 
write-host "`n[$scriptName] PROPFILE  : $PROPFILE"
if ( -Not ( Test-Path $PROPFILE -pathtype leaf ) ) {
    ERRMSG "[PROPFILE_NOT_FOUND] PROPFILE ($PROPFILE) not found" 4456
} else {
	if ($aeskey) {
	    $key = @()
	    $key = $aeskey.Split('-')
	    $secureFileInMemory = Get-Content $PROPFILE | ConvertTo-SecureString -Key $key
	    $unencryptedFileInMemory = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureFileInMemory))
	    $propertiesArray = $unencryptedFileInMemory -Split "\r?\n"
	} else {
	    $propertiesArray = @(get-content $PROPFILE)
	}
}

if ($TOKENFILE) {
    if (Test-Path $TOKENFILE) {
        write-host "[$scriptName] TOKENFILE : $TOKENFILE"
        $TOKENFILE = (Get-ChildItem $TOKENFILE).FullName
        $transformed = @(Get-Content $TOKENFILE)
    } else {
	    ERRMSG "[TOKENFILE_NOT_FOUND] TOKENFILE ($TOKENFILE) not found" 4457
    }
}

if ($aeskey) {
    write-host "[$scriptName] aeskey    : supplied, replacement values masked"
}
# Deleting lines starting with #, blank lines and lines with only spaces
Foreach ($line in $propertiesArray) {

#    write-host "[$scriptName] line = $line"
    # Don't process empty line
    if ($line) {
        # discard all characters after comment marker
        $regex = '.* #.*|^#'
        if ($line -match $regex) {
            $nameValue=$line.split("#")
            $nameValue=$nameValue[0]
        } else {
            $nameValue = $line
	    }

        # Do not attempt any processing when a line is just a comment
        if ($nameValue) {
            $name, $value = $nameValue -split '=', 2
    
            # If token file is supplied, detokenise file (in situ)
            if ($TOKENFILE) {
				$i = 0
				if ( $env:CDAF_OVERRIDE_TOKEN ) {
					$token = $env:CDAF_OVERRIDE_TOKEN + $name + $env:CDAF_OVERRIDE_TOKEN
				} else {
					$token = "%" + $name + "%"
				}
                foreach ($record in $transformed) {
                    if ($record -match "$token") {
                        if ($aeskey) {
                            write-host "Found $token, replacing with $(MASKED $token) (MASKED)"
                        } else {
							if ( $env:propldAction -eq 'resolve' ) {
								write-host "Found $token, replacing with $value"
								$value = invoke-expression "resolveContent"
							} elseif ($env:propldAction -eq 'reveal') {
								$value = invoke-expression "resolveContent"
								write-host "Found $token, replacing with $value"
							} else {
								write-host "Found $token, replacing with $value"
							}
                        }
                        $transformed[$i] = ($transformed[$i]).Replace("$token","$value")
                    }
                    $i++
                }
            } else { # If token file is not supplied, echo strings for instantiating as variables (cannot instantiate here as they will be out of scope)
				if ( $env:propldAction -eq 'resolve' ) {
					write-host "[$scriptName]   $name = $value"
					$value = invoke-expression "resolveContent"
				} elseif ($env:propldAction -eq 'reveal') {
					$value = invoke-expression "resolveContent"
					write-host "[$scriptName]   $name = $value"
				} else {
					write-host "[$scriptName]   $name = $value"
				}

				$loadVariable = "`$$name='$value'"
				Write-Output "$loadVariable"
            }
        }
    }
} 

# High performing file write https://blogs.technet.microsoft.com/gbordier/2009/05/05/powershell-and-writing-files-how-fast-can-you-write-to-a-file/
if ( $TOKENFILE ) {
	try {
	    $stream = [System.IO.StreamWriter] $TOKENFILE
	    foreach ($record in $transformed) {
	          $stream.WriteLine($record)
	    }
	    $stream.close()
	} catch {
		$message = $_.Exception.Message
		$_.Exception | format-list -force
		$_.Exception.StackTrace
		ERRMSG "[TRANSFORM_TOKEN_ERROR] Failure in High performing file write $TOKENFILE" 4458
	}
}
