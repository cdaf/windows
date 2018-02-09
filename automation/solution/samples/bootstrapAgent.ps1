$scriptName = 'bootstrapAgent.ps1'

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

cmd /c "exit 0"
# Use the CDAF provisioning helpers
Write-Host "`n[$scriptName] ---------- start ----------`n"

if ( Test-Path "./automation/provisioning" ) {
	$atomicPath = '.'
} else {
	if ( Test-Path "c:\vagrant" ) {
		$atomicPath = 'c:\vagrant'
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
$error.clear()
exit 0 