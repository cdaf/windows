Param (
	[string]$serverpath,
	[string]$driveLetter,
	[string]$username,
	[string]$userpass
)

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

$scriptName = 'addMount.ps1'
Write-Host "`n[$scriptName] ---------- start ----------"
if ($serverpath) {
    Write-Host "[$scriptName] serverpath  : $serverpath"
} else {
    Write-Host "[$scriptName] serverpath not supplied, exit with 1"; exit 1
}

if ($driveLetter) {
    Write-Host "[$scriptName] driveLetter : $driveLetter"
} else {
	$driveLetter = 'W'
    Write-Host "[$scriptName] driveLetter : $driveLetter (default)"
}

if ($username) {
    Write-Host "[$scriptName] username    : $username"
} else {
	$username = 'vagrant'
    Write-Host "[$scriptName] username    : $username (default)"
}

if ($userpass) {
    Write-Host "[$scriptName] userpass    : `$userpass"
} else {
	$userpass = 'vagrant'
    Write-Host "[$scriptName] userpass    : $userpass (default)"
}

if ( Test-Path "C:\vagrant" ) {
	$workspace = 'C:\vagrant'
} else {
	$workspace = $(pwd)
}

$psexec = "$workspace\SysinternalsSuite\PsExec.exe"
if ( Test-Path $psexec ) {
    Write-Host "[$scriptName] $psexec exists, download not required"
} else {
	executeExpression "mkdir $workspace\SysinternalsSuite"
	$zipFile = "SysinternalsSuite.zip"
	$url = "https://download.sysinternals.com/files/$zipFile"
	executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$workspace\$zipFile')"
	executeExpression "Add-Type -AssemblyName System.IO.Compression.FileSystem"
	executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory('$workspace\$zipfile', '$workspace\SysinternalsSuite')"
}

# Reset $LASTEXITCODE
cmd /c exit 0

if ( Test-Path "C:\addMount.bat" ) {
	executeExpression "rm C:\addMount.bat"
}

Add-Content C:\addMount.bat '@echo off'
Add-Content C:\addMount.bat 'echo net use %1: %2 /user:%3 ******** /persistent:yes'
Add-Content C:\addMount.bat 'net use %1: %2 /user:%3 %4 /persistent:yes'
Add-Content C:\addMount.bat 'set result=%errorlevel%'
Add-Content C:\addMount.bat 'if %result% NEQ 0 ('
Add-Content C:\addMount.bat '	echo [%~nx0] echo net use %1: %2 /user:%3 ******** /persistent:yes failed!'
Add-Content C:\addMount.bat '	echo [%~nx0] Errorlevel = %result%'
Add-Content C:\addMount.bat '	timeout 30'
Add-Content C:\addMount.bat '	exit /b %result%'
Add-Content C:\addMount.bat ')'

executeExpression "cat C:\addMount.bat"

Write-Host "`n[$scriptName] See https://peter.hahndorf.eu/blog/WorkAroundSysinternalsLicenseP.html"
executeExpression "& reg.exe ADD `"HKCU\Software\Sysinternals\PsExec`" /v EulaAccepted /t REG_DWORD /d 1 /f"


Write-Host "`n[$scriptName] `$proc = Start-Process -FilePath `"$psexec`" -ArgumentList `"-i -s cmd /c `"C:\addMount.bat $driveLetter $serverpath $username `$userpass`"`" -PassThru -Wait"
$proc = Start-Process -FilePath "$psexec" -ArgumentList "-i -s cmd /c `"C:\addMount.bat $driveLetter $serverpath $username $userpass`"" -PassThru -Wait
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

Write-Host "`n[$scriptName] ---------- finish ----------"
