Param (
	[string]$uri,
	[string]$mediaDir,
	[string]$md5
)
$scriptName = 'GetMedia.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($uri) {
    Write-Host "[$scriptName] uri      : $uri"
} else {
    Write-Host "[$scriptName] uri not supplied, exiting"
    exit 101
}

if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir : $mediaDir"
} else {
	$mediaDir = 'C:\.provision'
    Write-Host "[$scriptName] mediaDir : $mediaDir (default)"
}

if ($md5) {
    Write-Host "[$scriptName] md5      : $md5"
} else {
    Write-Host "[$scriptName] md5      : (not supplied)"
}

# Create media cache if missing
if (!( Test-Path $mediaDir )) {
	$result = executeExpression "mkdir $mediaDir"
	Write-Host "[$scriptName] Created $result`n"
}

$filename = $uri.Substring($uri.LastIndexOf("/") + 1)
$fullpath = $mediaDir + '\' + $filename
if ( Test-Path $fullpath ) {
	Write-Host "[$scriptName] $fullpath exists, download not required"
} else {
	executeExpression "(New-Object System.Net.WebClient).DownloadFile(`"`$uri`", `"`$fullpath`")" 
}

if ( $md5 ) {
	Write-Host
	$hashValue = executeExpression "Get-FileHash `"$fullpath`" -Algorithm MD5"
	if ($hashValue = $md5) {
		Write-Host "[$scriptName] MD5 check successful"
	} else {
		Write-Host "[$scriptName] MD5 check failed! Halting with `$lastexitcode 65"; exit 65
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
exit 0