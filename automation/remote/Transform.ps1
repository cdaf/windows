# Generic argument loading because propfile maybe a string or an array
$PROPFILE   = $args[0]
$TOKENFILE  = $args[1]
$aeskey     = $args[2]

function taskException ($taskName) {
    write-host "[$scriptName] Caught an exception executing $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    write-host
    throw "$scriptName HALT"
}

function throwErrorlevel ($taskName, $trappedExit) {
    write-host "[$scriptName] Trapped DOS exit code : $trappedExit" -ForegroundColor Red

    If ($RELEASE -eq "remote") {
        write-host
        write-host "[$scriptName] Called from DOS, returning exit code as errorlevel" -ForegroundColor Blue
        $host.SetShouldExit($trappedExit)
    } else {
        write-host
        write-host "[$scriptName] Called from PowerShell, throwing error" -ForegroundColor Blue
        throw "$taskName $trappedExit"
    }
}

$scriptName = $myInvocation.MyCommand.Name 
write-host "`n[$scriptName] PROPFILE  : $PROPFILE"
if (-Not (Test-Path $PROPFILE) ) {
    $exitCode=61
    write-host "[$scriptName] PROPFILE ($PROPFILE) not found, returning exit $exitCode"
    throwErrorlevel "PROPFILE_NOT_FOUND" $exitCode
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
        $exitCode=62
        write-host "[$scriptName] TOKENFILE ($TOKENFILE) not found, returning exit $exitCode"
        throwErrorlevel "TOKENFILE_NOT_FOUND" $exitCode
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
            if ( $name -like "*.*" ) {
                write-host "[$scriptName] Ignoring $name as contains '.'"
            } else {
                if ( $value -like "`$*" ) {
                    $value = Invoke-Expression $value
                }
    
                # If token file is supplied, detokenise file (in situ)
                if ($TOKENFILE) {
                    $i = 0
                    $token = "%" + $name + "%"
                    foreach ($record in $transformed) {
                        if ($record -match "$token") {
	                        if ($aeskey) {
    	                        write-host "Found $token, replacing with *****************"
	                        } else {
    	                        write-host "Found $token, replacing with $value"
	                        }
                            $transformed[$i] = ($transformed[$i]).Replace("$token","$value")
                        }
                        $i++
                    }
                } else { # If token file is not supplied, echo strings for instantiating as variables (cannot instantiate here as they will be out of scope)
                    $loadVariable = "`$$name=`"$value`""
                    Write-Output "$loadVariable"
                    write-host "[$scriptName]   $name = $value"
                }
            }
        }
    }
} 

# High performing file write https://blogs.technet.microsoft.com/gbordier/2009/05/05/powershell-and-writing-files-how-fast-can-you-write-to-a-file/
if ($TOKENFILE) {
    $stream = [System.IO.StreamWriter] $TOKENFILE
    foreach ($record in $transformed) {
          $stream.WriteLine($record)
    }
    $stream.close()
}
