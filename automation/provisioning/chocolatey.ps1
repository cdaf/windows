Param (
	[string]$mediaDir
)

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

$scriptName = 'chocolatey.ps1'
Write-Host "`n[$scriptName] ---------- start ----------"
if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = '/.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	Write-Host "[$scriptName]   $(mkdir $mediaDir) created"
}

Write-Host
$file = 'install.ps1'
$fullpath = $mediaDir + '\' + $file
if ( Test-Path $fullpath ) {
	Write-Host "[$scriptName] $fullpath exists, download not required"
} else {

	$uri = 'https://chocolatey.org/' + $file
	executeExpression "(New-Object System.Net.WebClient).DownloadFile(`"$uri`", `"$fullpath`")"
}

try {
	$argList = @("$fullpath")
	Write-Host "[$scriptName] Start-Process -FilePath 'powershell' -ArgumentList $argList -PassThru -Wait"
	$proc = Start-Process -FilePath 'powershell' -ArgumentList $argList -PassThru -Wait
} catch {
	Write-Host "[$scriptName] $file Install Exception : $_" -ForegroundColor Red
	exit 200
}

# Reload the path (without logging off and back on)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "`n[$scriptName] ---------- stop -----------`n"
exit 0