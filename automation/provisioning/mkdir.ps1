Param (
	[string]$directoryName,
	[string]$userName
)

cmd /c "exit 0"
$Error.Clear()
$scriptName = 'mkdir.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 10 }
	} catch { echo $_.Exception|format-list -force; exit 11 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 12 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------`n"
if ($directoryName) {
    Write-Host "[$scriptName] directoryName : $directoryName"
} else {
    Write-Host "[$scriptName] directoryName not supplied, exiting!"
    exit 100
}

if ($userName) {
    Write-Host "[$scriptName] userName      : $userName"
} else {
    Write-Host "[$scriptName] userName      : (not supplied, ACL changes will not be attempted)"
}

if ( Test-Path $directoryName ) {
	Write-Host "[$scriptName] Directory $directoryName already exists, no action attempted."
} else {
	executeExpression "New-Item -ItemType Directory -Force -Path `'$directoryName`'"
}
$newDir = executeExpression "New-Item -ItemType Directory -Force -Path `'$directoryName`'"
Write-Host "Created $($newDir.FullName)"

if ($userName) {
	Write-Host "`n[$scriptName] List ACL before changes"
	Get-Acl $directoryName | Format-List
	$acl = Get-Acl $directoryName
	$permission = $userName,"FullControl","Allow"
	$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
	$acl.SetAccessRule($accessRule)
	$acl | Set-Acl $directoryName
	Write-Host "`n[$scriptName] List ACL after changes"
	Get-Acl $directoryName | Format-List
}

Write-Host "`n[$scriptName] ---------- stop -----------"
