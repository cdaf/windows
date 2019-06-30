
cmd /c "exit 0"
$scriptName = 'bootstrapTarget.ps1'

function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------`n"

if ( Test-Path ".\automation\remote\capabilities.ps1" ) {
    Write-Host "[$scriptName] CDAF directories found in workspace"
	$atomicPath = '.'
} else {
	if ( Test-Path "/vagrant" ) {
		$atomicPath = '/vagrant'
	    Write-Host "[$scriptName] CDAF directories found in vagrant mount"
	} else {
	    Write-Host "[$scriptName] Cannot find CDAF directories in workspace or /vagrant, so downloading from internet"
		Write-Host "[$scriptName] Download Continuous Delivery Automation Framework"
		Write-Host "[$scriptName] `$zipFile = 'WU-CDAF.zip'"
		$zipFile = 'WU-CDAF.zip'
		Write-Host "[$scriptName] `$url = `"http://cdaf.io/static/app/downloads/$zipFile`""
		$url = "http://cdaf.io/static/app/downloads/$zipFile"
		executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$PWD\$zipFile')"
		executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
		executeExpression '[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$zipfile", "$PWD")'
		executeExpression 'cat .\automation\CDAF.windows'
		$atomicPath = '.'
	}
}
Write-Host "[$scriptName] `$atomicPath = $atomicPath"

Write-Host "[$scriptName] List components of the base image`n"
executeExpression "$atomicPath\automation\remote\capabilities.ps1"

Write-Host "`n[$scriptName] ---------- stop ----------"
