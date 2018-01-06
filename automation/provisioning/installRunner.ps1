Param (
  [string]$url,
  [string]$token,
  [string]$name,
  [string]$tags,
  [string]$executor,
  [string]$serviceAccount,
  [string]$saPassword,
  [string]$tlsCAFile,
  [string]$mediaDirectory
)
$scriptName = 'installRunner.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; Get-EventLog system -newest 5 | Format-List; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "`n[$scriptName] Refer to https://docs.gitlab.com/runner/install/windows.html"
Write-Host "`n[$scriptName] ---------- start ----------"
if ( $url ) {
	Write-Host "[$scriptName] url            : $url"
} else {
	Write-Host "[$scriptName] url            : (not supplied, will just extract the agent software)"
}

if ( $token ) {
	Write-Host "[$scriptName] token          : `$token"
} else {
	Write-Host "[$scriptName] token          : (not supplied)"
}

if ( $name ) {
	Write-Host "[$scriptName] name           : $name"
} else {
	$name = "$env:COMPUTERNAME"
	Write-Host "[$scriptName] name           : $name (not supplied, set to default)"
}

if ( $tags ) {
	Write-Host "[$scriptName] tags           : $tags"
} else {
	$tags = "$env:COMPUTERNAME"
	Write-Host "[$scriptName] tags           : $tags (not supplied, set to default)"
}

if ( $executor ) {
	Write-Host "[$scriptName] executor       : $executor"
} else {
	$executor = 'shell'
	Write-Host "[$scriptName] executor       : $executor (not supplied, set to default)"
}

if ( $serviceAccount ) {
	Write-Host "[$scriptName] serviceAccount : $serviceAccount"
} else {
	Write-Host "[$scriptName] serviceAccount : (not supplied)"
}

if ( $saPassword ) {
	Write-Host "[$scriptName] saPassword     : `$saPassword"
} else {
	Write-Host "[$scriptName] saPassword     : (not supplied)"
}

if ( $tlsCAFile ) {
	Write-Host "[$scriptName] tlsCAFile      : $tlsCAFile"
} else {
	Write-Host "[$scriptName] tlsCAFile      : (not supplied)"
}

if ( $mediaDirectory ) {
	Write-Host "[$scriptName] mediaDirectory : $mediaDirectory"
} else {
	$mediaDirectory = 'C:\.provision'
	Write-Host "[$scriptName] mediaDirectory : $mediaDirectory (not supplied, set to default)"
}

if (!( Test-Path "C:\GitLab-Runner" )) {
	Write-Host "[$scriptName] Create runtime directory $(mkdir C:\GitLab-Runner)"
	Write-Host "[$scriptName] Add C:\GitLab-Runner to PATH and reload path"
	[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\GitLab-Runner", [EnvironmentVariableTarget]::Machine)
	$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

$versionTest = cmd /c gitlab-runner --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	cmd /c "exit 0" # reset $LASTEXITCODE
## v9.5 of the runner
#	$fullpath = $mediaDirectory + '\gitlab-ci-multi-runner-windows-amd64.exe'
#	if (!( Test-Path $fullpath )) {
#		(New-Object System.Net.WebClient).DownloadFile("https://gitlab-ci-multi-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-ci-multi-runner-windows-amd64.exe", "$fullpath")
#	} 
## v10.x of the runner
	$fullpath = $mediaDirectory + '\gitlab-runner-windows-amd64.exe'
	if (!( Test-Path $fullpath )) {
		executeExpression "(New-Object System.Net.WebClient).DownloadFile('https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-windows-amd64.exe', '$fullpath')"
	} 
	executeExpression "Copy-Item $fullpath 'C:\GitLab-Runner\gitlab-runner.exe'"
}

$versionTest = cmd /c gitlab-runner --version 2`>`&1
if ( $LASTEXITCODE -ne 0 ) {
	Write-Host "GitLab Runner install failed!"; exit $LASTEXITCODE
} else {
	$versionLine = $(foreach ($line in $versionTest) { Select-String  -InputObject $line -CaseSensitive "Version" })
	$arr = $versionLine -split ':'
	Write-Host "[$scriptName] gitlab-runner  : $($arr[1].replace(' ',''))"
}

executeExpression "cd C:\GitLab-Runner"

$printList = "register --non-interactive --url $url --registration-token `$token --name $name --tag-list '$tags' --executor $executor --locked=false"
$argList = "register --non-interactive --url $url --registration-token $token --name $name --tag-list '$tags' --executor $executor --locked=false"

if ( $tlsCAFile ) {
	$printList = $printList + " --tls-ca-file $tlsCAFile"
	$argList = $argList + " --tls-ca-file $tlsCAFile"
}

Write-Host "[$scriptName] Start-Process gitlab-runner -PassThru -Wait -NoNewWindow -ArgumentList `"$printList`""
$proc = Start-Process gitlab-runner -PassThru -Wait -NoNewWindow -ArgumentList $argList
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Registration Failed! Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

$arguments = 'install'
if ( $serviceAccount ) {
	$arguments = $arguments + " --user $serviceAccount --password"
	Write-Host "[$scriptName] Start-Process gitlab-runner -PassThru -Wait -NoNewWindow -ArgumentList `"$arguments `$saPassword`""
} else {
	Write-Host "[$scriptName] Start-Process gitlab-runner -PassThru -Wait -NoNewWindow -ArgumentList `"$arguments`""
}

if ( $saPassword ) {
	$arguments = $arguments + " $saPassword"
}

$proc = Start-Process gitlab-runner -PassThru -Wait -NoNewWindow -ArgumentList $arguments
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Install Failed! Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

Write-Host "[$scriptName] Start Service using commandlet as gitlab-runner start can fail silently"
executeExpression "Start-Service gitlab-runner"

Write-Host "`n[$scriptName] ---------- stop -----------`n"
exit 0