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

function downloadAndInstall ($url, $installer) {
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
}

# As at dotnet 2 install files have changed https://www.microsoft.com/net/download/dotnet-core/2.1
# ASP.NET Core/.NET Core	dotnet-hosting-2.1.x-win.exe
# ASP.NET Core Installer	aspnetcore-runtime-2.1.x-win-x64.exe
# .NET Core Binaries		dotnet-runtime-2.1.x-win-x64.exe

cmd /c "exit 0"
Write-Host "`n[$scriptName] ---------- start ----------"
if ( $sdk ) {
	Write-Host "[$scriptName] sdk      : $sdk (choices yes, no or asp)"
} else {
	$sdk = 'no'
	Write-Host "[$scriptName] sdk      : $sdk (default, choices yes, no or asp)"
}

if ( $version ) {
	Write-Host "[$scriptName] version  : $version"
} else {
	if ( $sdk -eq 'yes' ) {
		$version = '2.1.302'
	} else {
		$runtimeRootURL = 'https://download.microsoft.com/download/1/f/7/1f7755c5-934d-4638-b89f-1f4ffa5afe89'
		$version = '2.1.2'
	} 
	Write-Host "[$scriptName] version  : $version (default)"
}

if ( $mediaDir ) {
	Write-Host "[$scriptName] mediaDir : $mediaDir`n"
} else {
	$mediaDir = 'C:\.provision'
	Write-Host "[$scriptName] mediaDir : $mediaDir (not passed, set to default)`n"
}

# Create media cache if missing
if ( Test-Path $mediaDir ) {
    Write-Host "`n[$scriptName] `$mediaDir ($mediaDir) exists"
} else {
	Write-Host "[$scriptName] Created $(mkdir $mediaDir)"
}

if ( $sdk -eq 'asp' ) {
	$file = "aspnetcore-runtime-${version}-win-x64.exe"
	$url = "${runtimeRootURL}/${file}"
	$installer = "${mediaDir}\${file}"
	downloadAndInstall $url $installer	
}

if ( $sdk -eq 'yes' ) {
	$file = "dotnet-sdk-${version}-win-x64.exe"
	$url = "https://download.microsoft.com/download/4/0/9/40920432-3302-47a8-b13c-bbc4848ad114/$file"
} else {
	$file = "dotnet-hosting-${version}-win.exe"
	$url = "${runtimeRootURL}/${file}"	
} 

$installer = "${mediaDir}\${file}"
downloadAndInstall $url $installer

Write-Host "[$scriptName] Reload path (without logging off and back on) " -ForegroundColor Green
$env:Path = executeExpression "[System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')"

$(dotnet --info | select-string -pattern 'Version')
if ($versionTest -like '*not recognized*') {
	Write-Host "  dotnet core not installed! Exiting with error 666"; exit 666
} else {
	$versionLine = $(foreach ($line in dotnet) { Select-String  -InputObject $line -CaseSensitive "Version" })
	if ( $versionLine ) {
	$arr = $versionLine -split ':'
		Write-Host "  dotnet core : $($arr[1])"
	} else {
		Write-Host "  dotnet core : $versionTest"
	}
}

Write-Host "`n[$scriptName] ---------- stop -----------"
exit 0