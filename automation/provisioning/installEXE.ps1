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

$scriptName = 'installEXE.ps1'
Write-Host
Write-Host "Generic executable runner"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$exeFile = $args[0]
if ($exeFile) {
    Write-Host "[$scriptName] exeFile : $exeFile"
} else {
    Write-Host "[$scriptName] Executable file not passed, exiting with code 1";exit 1
}

if (!(Test-Path $exeFile)) {
    Write-Host "[$scriptName] $exeFile not found, exiting with code 2";exit 2
}

$opt_arg = $args[1]
if ($opt_arg) {
    Write-Host "[$scriptName] opt_arg : $opt_arg"
} else {
    Write-Host "[$scriptName] opt_arg : (not supplied)"
}

if ($env:interactive) {
	Write-Host
    Write-Host "[$scriptName]   env:interactive is set ($env:interactive), run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
	$logToConsole = 'true'
} else {
    $sessionControl = '-PassThru -Wait'
	$logToConsole = 'false'
}

Write-Host
if ($opt_arg) {
	executeExpression "`$proc = Start-Process -FilePath `"$exeFile`" -ArgumentList `'$opt_arg`' $sessionControl"
} else {
	executeExpression "`$proc = Start-Process -FilePath `"$exeFile`" $sessionControl"
}
Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
