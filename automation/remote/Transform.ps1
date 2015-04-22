function taskException ($taskName) {
    write-host "[$scriptName] Caught an exception excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($_.Exception.Message)" -ForegroundColor Red
	write-host
    throw "$scriptName HALT"
}

$PROPFILE   = $args[0]
$TOKENFILE  = $args[1]

$scriptName = $myInvocation.MyCommand.Name 
write-host 
write-host "[$scriptName] PROPFILE : $PROPFILE"
if (-Not (Test-Path $PROPFILE) ) { taskException "Properties file ($PROPFILE) not found!" }

if ($TOKENFILE) {
	if (Test-Path $TOKENFILE) {
		write-host "[$scriptName] TOKENFILE = $TOKENFILE"
	} else {
		taskException "Token File ($TOKENFILE) not found!"
	}
}

# Deleting lines starting with #, blank lines and lines with only spaces

Foreach ($line in get-content $PROPFILE) {

#	write-host "[$scriptName] line = $line"
    # Don't process empty line
    if ($line) {

        # discard all characters after comment marker
        $nameValue=$line.split("#")
        $nameValue=$nameValue[0]

#		write-host "[$scriptName] nameValue = $nameValue"
        # Do not attempt any processing when a line is just a comment
        if ($nameValue) {

			$data = $nameValue.split("=")
			$value = $data[1]

			# If token file is supplied, detokenise file (in situ)
			if ($TOKENFILE) { 

				$name = "%" + $data[0] + "%"
				Foreach ($record in get-content $TOKENFILE) {
#					write-host "[$scriptName] record = $record"

					if ($record -match "$name") {
						write-host "Found $name, replacing with $value"
					}
					$newLine = $record -replace "$name","$value"
					Add-Content newFile.txt $newLine

				}
				Move-Item newFile.txt $TOKENFILE -force

			# If token file is not supplied, echo strings for instantiating as variables (cannot instantiate here as they will be out of scope)
			} else {

				$name = $data[0]
				$loadVariable = "`$$name=`"$value`""
				Write-Output "$loadVariable"
				write-host "[$scriptName]   $name = $value"
			}
        }
    }
} 
