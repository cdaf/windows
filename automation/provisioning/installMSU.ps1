$scriptName = 'installMSU.ps1'
Write-Host "`n[$scriptName] Generic MSU installer"
Write-Host "`n[$scriptName] ---------- start ----------"
$msuFile = $args[0]
if ($msuFile) {
    Write-Host "[$scriptName] msuFile          : $msuFile"
} else {
    Write-Host "[$scriptName] MSI file not supplied, exiting with error code 1"; exit 1
}
Write-Host
if ( Test-Path $msuFile ) {
	$fileName = Split-Path $msuFile -leaf
} else {
	Write-Host "[$scriptName] $msuFile not found, exiting with error code 2"; exit 2
}

$opt_arg = $args[1]
if ($opt_arg) {
    Write-Host "[$scriptName] opt_arg          : $opt_arg"
} else {
    Write-Host "[$scriptName] opt_arg          : (not supplied)"
}

if ($env:interactive) {
    Write-Host "[$scriptName] `$env:interactive : $env:interactive, run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
} else {
    $sessionControl = '-PassThru -Wait'
}

Write-Host

try {
	$argList = @('/quiet', '/norestart')

	$proc = executeExpression "Start-Process -FilePath `'$msuFile`' -ArgumentList `'$argList`' $sessionControl"
    if ( $proc.ExitCode -ne 0 ) {
		Write-Host "`n[$scriptName] Install Failed, see log file (c:\windows\logs\CBS\CBS.log) for details. Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
        exit $proc.ExitCode
    }
} catch {
	Write-Host "[$scriptName] PowerShell Install Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host