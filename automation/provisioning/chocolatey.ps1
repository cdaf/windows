Param (
	[string]$mediaDir
)

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$exitCode = 0
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
	} catch { echo $_.Exception|format-list -force; $exitCode = 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; $exitCode = 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; $exitCode = $LASTEXITCODE }
    if ( $exitCode -ne 0 ) {
    	if ( Test-Path "$env:ProgramData\chocolatey\logs\chocolatey.log" ) {
    		Write-Host "[$scriptName] List $env:ProgramData\chocolatey\logs\chocolatey.log"
    		Get-Content "$env:ProgramData\chocolatey\logs\chocolatey.log"
		} else {
    		Write-Host "[$scriptName] Log ($env:ProgramData\chocolatey\logs\chocolatey.log) not created"
		}
    	exit $exitCode
	}
    return $output
}

cmd /c "exit 0"
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
	Write-Host "[$scriptName] $file does not exist in $mediaDir, listing contents"
	try {
		Get-ChildItem $mediaDir | Format-Table name
	    if(!$?) { $fullpath = listAndContinue }
	} catch { $fullpath = listAndContinue }

	Write-Host "[$scriptName] Attempt download"
	executeExpression "(New-Object System.Net.WebClient).DownloadFile('$uri', '$fullpath')"
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
Write-Host "[$scriptName] Reload path " -ForegroundColor Green
$env:Path = executeExpression "[System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')"

Write-Host "`n[$scriptName] ---------- stop -----------`n"
$error.clear()
exit 0