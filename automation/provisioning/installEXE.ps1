# Cannot use parameters as opt_arg may contain parameters itself

$scriptName = 'installEXE.ps1'

Write-Host "`n[$scriptName] ---------- start ----------"
$exeFile = $args[0]
if ($exeFile) {
    Write-Host "[$scriptName] exeFile : $exeFile"
} else {
    Write-Host "[$scriptName] Executable file not passed, exiting with code 1";exit 1
}
if (!(Test-Path $exeFile)) {
    Write-Host "[$scriptName] $exeFile not found, exiting with code 2";exit 2
}
$arglist = "$exeFile"

$opt_arg = $args[1]
if ($opt_arg) {
    Write-Host "[$scriptName] opt_arg : $opt_arg"
	$arglist += " $opt_arg"
} else {
    Write-Host "[$scriptName] opt_arg : (not supplied)"
}
# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $arglist`""
}

if ($opt_arg) {
	Write-Host "`n[$scriptName] `$proc = Start-Process -FilePath `"$exeFile`" -ArgumentList `"$opt_arg`" -PassThru -Wait"
	$proc = Start-Process -FilePath "$exeFile" -ArgumentList "$opt_arg" -PassThru -Wait
} else {
	Write-Host "`n[$scriptName] `$proc = Start-Process -FilePath `"$exeFile`" -PassThru -Wait"
	$proc = Start-Process -FilePath "$exeFile" -PassThru -Wait
}
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

Write-Host "`n[$scriptName] ---------- stop ----------"
