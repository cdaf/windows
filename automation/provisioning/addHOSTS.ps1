Param (
	[string]$ipAddress,
	[string]$hostEntry
)

# Initialise
cmd /c "exit 0"
$Error.Clear()
$scriptName = 'addHOSTS.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1112 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red ; $error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				$error
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName] `$error[] = $error"; exit 1113
		}
	}
}

# In memory replacement performed to avoid dead-lock scenario when trying to use Get-Content / Set-Content commandlets
Write-Host "`n[$scriptName] ---------- start ----------`n"
if ($ipAddress) {
    Write-Host "[$scriptName] ipAddress : $ipAddress"
} else {
    Write-Host "[$scriptName] ipAddress not supplied!" ; exit 777
}

if ($hostEntry) {
    Write-Host "[$scriptName] hostEntry : $hostEntry"
} else {
    Write-Host "[$scriptName] hostEntry not supplied!" ; exit 776
}

$stringTest = $ipAddress.Split('.')
$isFQDN = foreach ($item in $stringTest) { if (! ( $item -match "^\d+$" )) { Write-Output $item } }
if ( $isFQDN ) {
    $ipAddress = ([System.Net.Dns]::GetHostAddresses($ipAddress))[0].IPAddressToString
    Write-Host "[$scriptName] Converted from FQDN to $ipAddress"
}


$hostsfile = 'C:\Windows\System32\drivers\etc\hosts'
$transformed = @(Get-Content $hostsfile)
$addEntry = $True
$i = 0
foreach ($record in $transformed) {
    if ($record -match " ${hostEntry}") {
        write-host "[$scriptName]   Replacing $($transformed[$i]) with $ipAddress ${hostEntry}"
        $transformed[$i] = "$ipAddress ${hostEntry}"
        $addEntry = $False
        break
    }
    $i++
}

if ( $addEntry ) {
	Write-Host "[$scriptName]   Existing entry not found, create $ipAddress ${hostEntry}"
	$transformed += "$ipAddress ${hostEntry}"
}

Write-Host "[$scriptName] Replace $hostsfile"
$stream = [System.IO.StreamWriter] $hostsfile
foreach ($record in $transformed) {
      $stream.WriteLine($record)
}
$stream.close()

executeExpression "Get-Content $hostsfile" 

Write-Host "`n[$scriptName] ---------- finish ----------`n"
