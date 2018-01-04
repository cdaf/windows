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

$printList = "register --non-interactive --url $url --registration-token `$token --name $name --tag-list '$tags' --executor $executor"
$argList = "register --non-interactive --url $url --registration-token $token --name $name --tag-list '$tags' --executor $executor"

if ( $tlsCAFile ) {
	$printList = $printList + " --tls-ca-file $tlsCAFile"
	$argList = $argList + " --tls-ca-file $tlsCAFile"
}

$fullpath = $mediaDirectory + '\gitlab-ci-multi-runner-windows-amd64.exe'
Write-Host "[$scriptName] Start-Process $fullpath -PassThru -Wait -NoNewWindow -ArgumentList `"$printList`""
$proc = Start-Process $fullpath -PassThru -Wait -NoNewWindow -ArgumentList $argList
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Registration Failed! Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

$arguments = 'install'
if ( $serviceAccount ) {
	$arguments = "--user $serviceAccount --password $saPassword"
}

Write-Host "[$scriptName] Start-Process $fullpath -PassThru -Wait -NoNewWindow -ArgumentList $arguments"
$proc = Start-Process $fullpath -PassThru -Wait -NoNewWindow -ArgumentList $arguments
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Install Failed! Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

Write-Host "[$scriptName] Start-Process $fullpath -PassThru -Wait -NoNewWindow -ArgumentList start"
$proc = Start-Process $fullpath -PassThru -Wait -NoNewWindow -ArgumentList start
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Start Failed! Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

Write-Host "`n[$scriptName] ---------- stop -----------`n"
exit 0