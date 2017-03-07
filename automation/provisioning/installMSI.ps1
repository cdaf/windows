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

$scriptName = 'installMSI.ps1'

Write-Host
Write-Host "[$scriptName] Generic MSI installer"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$msiFile = $args[0]
if ($msiFile) {
    Write-Host "[$scriptName] msiFile          : $msiFile"
} else {
    Write-Host "[$scriptName] MSI file not supplied, exiting with error code 1"; exit 1
}
Write-Host
if ( Test-Path $msiFile ) {
	$fileName = Split-Path $msiFile -leaf
} else {
	Write-Host "[$scriptName] $msiFile not found, exiting with error code 2"; exit 2
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

$logFile = $installDir = [Environment]::GetEnvironmentVariable('TEMP', 'user') + '\' + $fileName + '.log'
Write-Host "[$scriptName] logFile          : $logFile"

if (Test-Path $logFile) { 
	Write-Host; executeExpression "Remove-Item $logFile"
}

Write-Host
$argList = @(
	"/qn",
	"/L*V",
	"$logFile",
	"/i",
	"$msiFile",
	"$opt_arg"
)

# Perform Install
executeExpression "`$process = Start-Process -FilePath `'msiexec`' -ArgumentList `'$argList`' $sessionControl"

$failed = Select-String $logFile -Pattern "Installation failed"
if ( $failed  ) { 
	Select-String $logFile -Pattern "Installation success or error status"
	exit 4
}
Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
