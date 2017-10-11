Param (
  [string]$url,
  [string]$token,
  [string]$description,
  [string]$tags,
  [string]$executor,
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
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "[$scriptName] ---------- start ----------"
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

if ( $description ) {
	Write-Host "[$scriptName] description    : $description"
} else {
	$description = "Gitlab Runner Installed by $scriptName"
	Write-Host "[$scriptName] description    : $description (not supplied, set to default)"
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
	Write-Host "[$scriptName] executor       : (not supplied)"
}

if ( $mediaDirectory ) {
	Write-Host "[$scriptName] mediaDirectory : $mediaDirectory"
} else {
	$mediaDirectory = 'C:\.provision'
	Write-Host "[$scriptName] mediaDirectory : $mediaDirectory (not supplied, set to default)"
}

$printList = "register --non-interactive --url $url --registration-token `$token --description $description --tag-list $tags --executor $executor"
$argList = "register --non-interactive --url $url --registration-token $token --description $description --tag-list $tags --executor $executor"

$fullpath = $mediaDirectory + '\gitlab-ci-multi-runner-windows-amd64.exe'
Write-Host "[$scriptName] Start-Process $fullpath -ArgumentList $printList -PassThru -Wait"
$proc = Start-Process $fullpath -ArgumentList $argList -PassThru -Wait -NoNewWindow
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Install Failed! Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

Write-Host "[$scriptName] Start-Process $fullpath -ArgumentList install -PassThru -Wait"
$proc = Start-Process $fullpath -ArgumentList install -PassThru -Wait -NoNewWindow
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Install Failed! Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

Write-Host "[$scriptName] Start-Process $fullpath -ArgumentList start -PassThru -Wait"
$proc = Start-Process $fullpath -ArgumentList start -PassThru -Wait -NoNewWindow
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Install Failed! Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

Write-Host "`n[$scriptName] ---------- stop -----------`n"
exit 0