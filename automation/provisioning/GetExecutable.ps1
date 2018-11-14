Param (
	[string]$url,
	[string]$mediaDir,
	[string]$runTime,
	[string]$proxy
)
$scriptName = 'GetExecutable.ps1'

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
if ($url) {
    Write-Host "[$scriptName] url      : $url"
} else {
	$url = 'http://cdaf.azurewebsites.net/content/Database.exe'
    Write-Host "[$scriptName] url      : $url (default)"
}

if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = 'c:\.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

if ($runTime) {
    Write-Host "[$scriptName] runTime  : $runTime"
} else {
	$runTime = '$env:windir'
    Write-Host "[$scriptName] runTime  : $runTime (default)"
}

if ($proxy) {
    Write-Host "[$scriptName] proxy    : $proxy`n"
    executeExpression "[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('$proxy')"
} else {
    Write-Host "[$scriptName] proxy    : (not supplied)"
}

$file = Split-Path -Path  $url -Leaf

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

Write-Host
$fullpath = $mediaDir + '\' + $file
if ( Test-Path $fullpath ) {
	Write-Host "[$scriptName] $fullpath exists, download not required"
} else {
	Write-Host "[$scriptName] $file does not exist in $mediaDir, listing contents"
	try {
		Get-ChildItem $mediaDir | Format-Table name
	    if(!$?) { $fullpath = listAndContinue }
	} catch { $fullpath = listAndContinue }

	Write-Host "[$scriptName] Attempt download"
	executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$fullpath')"
}

executeExpression "Copy-Item `"$fullpath`" `"$runTime`""

Write-Host "`n[$scriptName] ---------- stop ----------"
