Param (
  [string]$exeFile,
  [string]$opt_arg
)
$scriptName = 'installEXE.ps1'

Write-Host "`n[$scriptName] ---------- start ----------"
if ($exeFile) {
    Write-Host "[$scriptName] exeFile : $exeFile"
} else {
    Write-Host "[$scriptName] Executable file not passed, exiting with code 1";exit 1
}
if (!(Test-Path $exeFile)) {
    Write-Host "[$scriptName] $exeFile not found, exiting with code 2";exit 2
}
$optParm = "-exeFile $exeFile"

if ($opt_arg) {
    Write-Host "[$scriptName] opt_arg : $opt_arg"
	$optParm += " -opt_arg $opt_arg"
} else {
    Write-Host "[$scriptName] opt_arg : (not supplied)"
}
# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $optParm`""
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
