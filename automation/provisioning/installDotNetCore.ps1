Param (
	[string]$sdk,
	[string]$mediaDir
)
$scriptName = 'installDotnetCore.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

cmd /c "exit 0"
Write-Host "`n[$scriptName] ---------- start ----------"
if ( $sdk ) {
	Write-Host "[$scriptName] sdk      : $sdk (choices yes or no)"
} else {
	$sdk = 'no'
	Write-Host "[$scriptName] sdk      : $sdk (default, choices yes or no)"
}

if ( $version ) {
	Write-Host "[$scriptName] version  : $version"
} else {
	if ( $sdk -eq 'yes' ) {
		$version = '2.1.4'
		$file = "dotnet-sdk-${version}-win-x64.exe"
		$url = "https://download.microsoft.com/download/1/1/5/115B762D-2B41-4AF3-9A63-92D9680B9409/$file"
	} else {
		$version = '2.0.5'
		$file = "dotnet-runtime-${version}-win-x64.exe"
		$url = "https://download.microsoft.com/download/1/1/0/11046135-4207-40D3-A795-13ECEA741B32/$file"
	} 
	Write-Host "[$scriptName] version  : $version (default)"
}

if ( $mediaDir ) {
	Write-Host "[$scriptName] mediaDir : $mediaDir`n"
} else {
	$mediaDir = 'C:\.provision'
	Write-Host "[$scriptName] mediaDir : $mediaDir (not passed, set to default)`n"
}

$installer = "${mediaDir}\${file}"
if ( Test-Path $installer ) {
	Write-Host "[$scriptName] Installer $installer found, download not required`n"
} else {
	Write-Host "[$scriptName] $file does not exist in $mediaDir, listing contents"
	try {
		Get-ChildItem $mediaDir | Format-Table name
	    if(!$?) { $installer = listAndContinue }
	} catch { $installer = listAndContinue }

	Write-Host "[$scriptName] Attempt download"
	executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$installer')"
}

$proc = executeExpression "Start-Process -FilePath '$installer' -ArgumentList '/INSTALL /QUIET /NORESTART /LOG $installer.log' -PassThru -Wait"
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

# Reload the path (without logging off and back on)
Write-Host "[$scriptName] Reload path " -ForegroundColor Green
$env:Path = executeExpression "[System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')"

$versionTest = cmd /c dotnet --version 2`>`&1
if ($versionTest -like '*not recognized*') {
	Write-Host "  dotnet core not installed! Exiting with error 666"; exit 666
} else {
	$versionLine = $(foreach ($line in dotnet) { Select-String  -InputObject $line -CaseSensitive "Version  " })
	if ( $versionLine ) {
	$arr = $versionLine -split ':'
		Write-Host "  dotnet core : $($arr[1])"
	} else {
		Write-Host "  dotnet core : $versionTest"
	}
}

Write-Host "`n[$scriptName] ---------- stop -----------"
exit 0