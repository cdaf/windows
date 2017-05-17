Param (
  [string]$url,
  [string]$mediaDir,
  [string]$runTime
)
$scriptName = 'GetExecutable.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
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

$exename = Split-Path -Path  $url -Leaf

# Provisionig Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName -url $url -mediaDir $mediaDir -runTime $runTime `""
}

if (!( Test-Path $mediaDir )) {
	Write-Host "[$scriptName] mkdir $mediaDir"
	mkdir $mediaDir
}

Write-Host
$fullpath = $mediaDir + '\' + $exename
if ( Test-Path $fullpath ) {
	Write-Host "[$scriptName] $fullpath exists, download not required"
} else {
	executeExpression "(New-Object System.Net.WebClient).DownloadFile(`"`$url`", `"`$fullpath`")" 
}

executeExpression "Copy-Item `"$fullpath`" `"$runTime`""

Write-Host "`n[$scriptName] ---------- stop ----------"
