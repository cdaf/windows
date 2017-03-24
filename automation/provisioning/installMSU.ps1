# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
}

$scriptName = 'installMSU.ps1'

Write-Host
Write-Host "[$scriptName] Generic MSU installer"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
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
	Write-Host "[$scriptName] Start-Process -FilePath `"$msuFile`" -ArgumentList $argList -PassThru -Wait"
	$proc = Start-Process -FilePath "$msuFile" -ArgumentList $argList -PassThru -Wait
} catch {
	Write-Host "[$scriptName] PowerShell Install Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host