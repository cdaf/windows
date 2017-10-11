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

$scriptName = 'installPython.ps1'
Write-Host "`n[$scriptName] ---------- start ----------`n"

$exeFile = 'python-3.6.3-amd64.exe'
$md5 = '89044FB577636803BF49F36371DCA09C'
$uri = "https://www.python.org/ftp/python/3.6.3/$exeFile"
executeExpression "(New-Object System.Net.WebClient).DownloadFile(`"`$uri`", `"`$(PWD)\$exeFile`")" 
$hashValue = executeExpression "Get-FileHash `"$(PWD)\$exeFile`" -Algorithm MD5"
if ($hashValue = $md5) {
	Write-Host "[$scriptName] MD5 ($md5) check successful"
} else {
	Write-Host "[$scriptName] MD5 ($md5) check failed! Halting with `$lastexitcode 65"; exit 65
}

$opt_arg = '/passive /quiet'
Write-Host "`n[$scriptName] `$proc = Start-Process -FilePath `"$(PWD)\$exeFile`" -ArgumentList `"$opt_arg`" -PassThru -Wait"
$proc = Start-Process -FilePath "$(PWD)\$exeFile" -ArgumentList "$opt_arg" -PassThru -Wait
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

# Determine if Python 3.6 has already been installed, if not, set path
if ( ! (Test-Path ~/AppData/Roaming/Python/Python36/Scripts)) {
	executeExpression "mkdir ~/AppData/Roaming/Python/Python36/Scripts" # default binary location for subsequent PiP installs
	$pathWithPython = $env:Path + ';' + (Get-Item ~/AppData/Local/Programs/Python/Python36).fullname + ';' + (Get-Item ~/AppData/Local/Programs/Python/Python36/Scripts).fullname + ';' + (Get-Item ~/AppData/Roaming/Python/Python36/Scripts).fullname
	executeExpression "[Environment]::SetEnvironmentVariable(`"Path`", `"$pathWithPython`", 'User')"
	$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

executeExpression "python.exe --version"
executeExpression "pip.exe --version"

Write-Host "`n[$scriptName] ---------- stop ----------`n"
