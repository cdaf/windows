Param (
	[string]$SOLUTION,
	[string]$BUILDNUMBER,
	[string]$TARGET
)

$scriptName = 'deliveryScript.ps1'
cmd /c "exit 0"

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		$result = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $result
}


Write-Host "`n[$scriptName] ---------- start ----------`n"
Write-Host "[$scriptName]   SOLUTION    : $SOLUTION"
Write-Host "[$scriptName]   BUILDNUMBER : $BUILDNUMBER"
Write-Host "[$scriptName]   TARGET      : $TARGET"

& ./Transform.ps1 $TARGET | ForEach-Object { invoke-expression $_ }

if ( Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Server\ServerLevels' ) {

	Write-Host "Compatibility setting`n"
	[Console]::OutputEncoding = [System.Text.Encoding]::Default
	
	Write-Host "Cleanup from previously failed builds`n"
	executeExpression "docker-compose down"
	executeExpression "docker-compose rm"
	
	Write-Host "Create Test SQL Server Container`n"
	executeExpression "docker-compose up -d"

} else {

	Write-Host "This operating system is not a server, please ensure SQL Server is running with sa account and password of Passw0rd!`n"

}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0