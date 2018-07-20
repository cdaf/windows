# Retry logic for connection issues, i.e. "Cannot retrieve the dynamic parameters for the cmdlet. PowerShell Gallery is currently unavailable.  Please try again later."
# Includes warning for "Cannot find a variable with the name 'PackageManagementProvider'. Cannot find a variable with the name 'SourceLocation'."
function executeRetry ($expression) {
	$exitCode = 1
	$wait = 10
	$retryMax = 3
	$retryCount = 0
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "$expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?" -ForegroundColor Red; $exitCode = 1 }
		} catch { Write-Host "[$scriptName] $_" -ForegroundColor Red; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] Warning, message in `$error[0] = $error" -ForegroundColor Yellow; $error.clear() } # do not treat messages in error array as failure
	    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { $exitCode = $LASTEXITCODE; Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red; cmd /c "exit 0" }
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with `$LASTEXITCODE = $exitCode.`n"
				exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Set TLS to version 1.1 or higher, Wait $wait seconds, then retry $retryCount of $retryMax"
				Write-Host "`$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'"
				$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
				executeExpression '[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols'
				sleep $wait
			}
		}
    }
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

$scriptName = 'installPython.ps1'
Write-Host "`n[$scriptName] Only Python 3 Supported"
Write-Host "`n[$scriptName] ---------- start ----------"
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = 'C:\.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

# Create media cache if missing
if ( Test-Path $mediaDir ) {
    Write-Host "`n[$scriptName] `$mediaDir ($mediaDir) exists"
} else {
	Write-Host "[$scriptName] Created $(mkdir $mediaDir)"
}

$file = 'python-3.6.3-amd64.exe'
$fullpath = $mediaDir + '\' + $file
if ( Test-Path $fullpath ) {
	Write-Host "[$scriptName] $fullpath exists, download not required"
} else {
	$md5 = '89044FB577636803BF49F36371DCA09C'
	$uri = "https://www.python.org/ftp/python/3.6.3/$exeFile"
	executeRetry "(New-Object System.Net.WebClient).DownloadFile('$uri', '$fullpath')" 
	$hashValue = executeExpression "Get-FileHash '$fullpath' -Algorithm MD5"
	if ($hashValue = $md5) {
		Write-Host "[$scriptName] MD5 ($md5) check successful"
	} else {
		Write-Host "[$scriptName] MD5 ($md5) check failed! Halting with `$lastexitcode 65"; exit 65
	}
}

$opt_arg = '/passive /quiet'
Write-Host "`n[$scriptName] `$proc = Start-Process -FilePath '$fullpath' -ArgumentList '$opt_arg' -PassThru -Wait"
$proc = Start-Process -FilePath "$fullpath" -ArgumentList "$opt_arg" -PassThru -Wait
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

# Determine if Python 3.6 has already been installed, if not, set path
if ( ! (Test-Path ~/AppData/Roaming/Python/Python36/Scripts)) {
	executeExpression "mkdir ~/AppData/Roaming/Python/Python36/Scripts" # default binary location for subsequent PiP installs
	$pathWithPython = $env:Path + ';' + (Get-Item ~/AppData/Local/Programs/Python/Python36).fullname + ';' + (Get-Item ~/AppData/Local/Programs/Python/Python36/Scripts).fullname + ';' + (Get-Item ~/AppData/Roaming/Python/Python36/Scripts).fullname
	executeExpression "[Environment]::SetEnvironmentVariable('Path', '$pathWithPython', 'User')"
	$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

executeExpression "python.exe --version"
executeExpression "pip.exe --version"

Write-Host "`n[$scriptName] ---------- stop ----------`n"
