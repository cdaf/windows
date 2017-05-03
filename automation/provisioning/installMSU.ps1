Param (
  [string]$msuFile,
  [string]$opt_arg,
  [string]$reboot
)
# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	$LASTEXITCODE = 0
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if ( $LASTEXITCODE -ne 0 ) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

$scriptName = 'installMSU.ps1'
Write-Host "`n[$scriptName] Generic MSU installer"
Write-Host "`n[$scriptName] ---------- start ----------"
if ($msuFile) {
    Write-Host "[$scriptName] msuFile : $msuFile"
} else {
    Write-Host "[$scriptName] MSI file not supplied, exiting with error code 1"; exit 1
}
Write-Host
if ( Test-Path $msuFile ) {
	$fileName = Split-Path $msuFile -leaf
} else {
	Write-Host "[$scriptName] $msuFile not found, exiting with error code 2"; exit 2
}

if ($opt_arg) {
    Write-Host "[$scriptName] opt_arg : $opt_arg"
} else {
    Write-Host "[$scriptName] opt_arg : (not supplied)"
}

if ($reboot) {
    Write-Host "[$scriptName] reboot  : $reboot"
    $optParm += "-reboot $reboot"
	$argList = @('/quiet')
} else {
	$reboot = 'no'
    Write-Host "[$scriptName] reboot  : $reboot (default)"
	$argList = @('/quiet', '/norestart')
}
# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $msuFile $opt_arg $optParm`""
}

if ($env:interactive) {
    Write-Host "[$scriptName] `$env:interactive : $env:interactive, run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
} else {
    $sessionControl = '-PassThru -Wait'
}

Write-Host

try {

	$proc = executeExpression "Start-Process -FilePath `'$msuFile`' -ArgumentList `'$argList`' $sessionControl"
	
    if ( $proc.ExitCode -ne 0 ) {
		switch ($proc.ExitCode) {
			2359302 {
				Write-Host "`n[$scriptName] Exit 2359302 MSU alreay installed, reboot maybe required.`n"
			}
			-2145124329 {
				Write-Host "`n[$scriptName] Exit -2145124329 MSU alreay installed.`n"
			}
			3010 {
				Write-Host "`n[$scriptName] Exit 3010 The requested operation is successful. Changes will not be effective until the system is rebooted.`n"
			}
		    default {
				Write-Host "`n[$scriptName] Install Failed, see log file (c:\windows\logs\CBS\CBS.log) for details. Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
		        exit $proc.ExitCode
		    }
        }
    }
} catch {
	Write-Host "[$scriptName] PowerShell Install Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host