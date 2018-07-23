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
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
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
Write-Host "`n[$scriptName] ---------- start ----------"
$version = $args[0]
if ($version) {
    Write-Host "[$scriptName] version  : $version"
} else {
	$version = '3'
    Write-Host "[$scriptName] version  : $version (default)"
}

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

if ($version -eq '3') {
	$file = 'python-3.6.3-amd64.exe'
	$md5 = '89044FB577636803BF49F36371DCA09C'
	$uri = "https://www.python.org/ftp/python/3.6.3/$file"
} else {
	$file = 'python-2.7.15.amd64.msi'
	$uri = "https://www.python.org/ftp/python/2.7.15/$file"
}

$fullpath = $mediaDir + '\' + $file
if ( Test-Path $fullpath ) {
	Write-Host "[$scriptName] $fullpath exists, download not required"
} else {
	$proxy = [System.Net.WebRequest]::GetSystemWebProxy()
	$proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
	$wc = new-object system.net.WebClient
	$wc.proxy = $proxy
	Write-Host "`$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'"
	$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
	executeExpression '[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols'
	executeRetry "`$wc.DownloadFile('$uri', '$fullpath')" 
	if ($md5) {
		$hashValue = executeExpression "Get-FileHash '$fullpath' -Algorithm MD5"
		if ($hashValue = $md5) {
			Write-Host "[$scriptName] MD5 ($md5) check successful"
		} else {
			Write-Host "[$scriptName] MD5 ($md5) check failed! Halting with `$lastexitcode 65"; exit 65
		}
	}
}

$opt_arg = '/passive /quiet'
Write-Host "`n[$scriptName] `$proc = Start-Process -FilePath '$fullpath' -ArgumentList '$opt_arg' -PassThru -Wait"
$proc = Start-Process -FilePath "$fullpath" -ArgumentList "$opt_arg" -PassThru -Wait
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

# Determine if Python has already been installed, if not, set path
if ($version -eq '3') {
	$scriptPath = '~/AppData/Roaming/Python/Python36/Scripts'
	$binPath = 'C:\Python36'
} else {

#	$fullpath = $mediaDir + '\get-pip.py'
#	executeRetry "`$wc.DownloadFile('https://bootstrap.pypa.io/get-pip.py', '$fullpath')"
#	executeExpression "python $fullpath"

	$scriptPath = '~/AppData/Roaming/Python/Python27/Scripts'
	$binPath = 'C:\Python27'
}

if ( ! (Test-Path $scriptPath)) {
	executeExpression "mkdir $scriptPath" # default binary location for subsequent PiP installs
}

Write-Host "`n[$scriptName] List current path before making changes"
$env:Path

# Set user (PiP) and machine (Python) paths
$pathWithPython = $env:Path + ';' + (Get-Item $scriptPath).fullname
executeExpression "[Environment]::SetEnvironmentVariable('Path', '$pathWithPython', 'User')"
$pathWithPython = $env:Path + ';' + (Get-Item $binPath).fullname
executeExpression "[Environment]::SetEnvironmentVariable('Path', '$pathWithPython', 'Machine')"
$pipPath = $binPath + '\Scripts'
$pathWithPython = $env:Path + ';' + (Get-Item $pipPath).fullname
executeExpression "[Environment]::SetEnvironmentVariable('Path', '$pathWithPython', 'Machine')"

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

executeExpression "python --version"
executeExpression "pip --version"

Write-Host "`n[$scriptName] ---------- stop ----------`n"
