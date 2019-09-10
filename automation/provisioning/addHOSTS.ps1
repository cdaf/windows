Param (
	[string]$ipAddress,
	[string]$hostEntry
)

# Initialise
cmd /c "exit 0"
$scriptName = 'addHOSTS.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
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
