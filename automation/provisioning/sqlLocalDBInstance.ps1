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

$scriptName = 'sqlLocalDBInstance.ps1'

Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$instanceName = $args[0]
if ($instanceName) {
    Write-Host "[$scriptName] instanceName          : $instanceName"
} else {
	$instanceName = 'MSSQLLocalDB'
    Write-Host "[$scriptName] instanceName          : $instanceName (not supplied, so default used)"
}

$exists = SqlLocalDB.exe info | findstr.exe $instanceName

Write-Host
if ( $exists ) {
	executeExpression "SqlLocalDB.exe start $instanceName"
} else {
	executeExpression "SqlLocalDB.exe create $instanceName"
	executeExpression "SqlLocalDB.exe start $instanceName"	
}

Write-Host
executeExpression "foreach (`$instance in SqlLocalDB.exe info ) { SqlLocalDB.exe info `$instance }"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
