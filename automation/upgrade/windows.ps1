$scriptName = 'cdafUpgrade.ps1'
cmd /c "exit 0"

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

Write-Host "`n[$scriptName] ---------- start ----------"

$zipFile = 'WU-CDAF.zip'
$cdafBase = 'http://cdaf.io/static/app/downloads'
$url = "${cdafBase}/${zipFile}"
$extract = "$env:TEMP\WU-CDAF"
if (Test-Path $extract ) {
	executeExpression "Remove-Item -Recurse -Force $extract"
}
executeExpression "mkdir $extract"
executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$extract\$zipfile')"
executeExpression "Add-Type -AssemblyName System.IO.Compression.FileSystem"
executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory('$extract\$zipfile', '$extract')"
 
executeExpression 'Remove-Item -Recurse .\automation\'
executeExpression 'Copy-Item -Recurse $extract\automation .'

git branch
if ( $LASTEXITCODE -eq 0 ) {
	executeExpression 'cd automation'
	executeExpression 'foreach ($file in Get-ChildItem) {git add $file}'
	executeExpression 'cd ..'
} else {
	svn ls
	if ( $LASTEXITCODE -eq 0 ) {
		executeExpression 'foreach ($file in Get-ChildItem) {svn add $file --force}'
	} else {
		cmd /c "exit 0"
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0
