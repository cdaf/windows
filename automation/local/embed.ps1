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

$scriptName = 'embed.ps1'
Write-Host
Write-Host "[$scriptName] Turn a file into an embedded string"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$fileIn = $args[0]
if ($fileIn) {
    Write-Host "[$scriptName] fileIn   : $fileIn (choices $configChoices)"
} else {
    Write-Host "[$scriptName] Input file not supplied, exiting!"
    exit 100
}

$fileOut = $args[1]
if ($fileOut) {
    Write-Host "[$scriptName] fileOut  : $fileOut"
} else {
	$fileOut = 'embedded.ps1'
    Write-Host "[$scriptName] fileOut  : $fileOut (default)"
}

Write-Host
Write-Host "[$scriptName] Test input file ($fileIn) exists"
$extension = [System.IO.Path]::GetExtension("$fileIn")
$verificationFile = 'testfile' + $extension

Write-Host
Write-Host "[$scriptName] Load input file ($fileIn)"
$ByteArray = [System.IO.File]::ReadAllBytes($fileIn)
$EncodedText = [System.Convert]::ToBase64String($ByteArray)

if (Test-Path $fileOut) {
	Write-Host
	Write-Host "[$scriptName] Delete Existing $fileOut"
	Remove-Item $fileOut
}

Write-Host
Write-Host "[$scriptName] Create script ($fileOut) which will generated the embedded file"
Add-Content $fileOut "`$EncodedText = `'$EncodedText`'"
Add-Content $fileOut "`$ByteArray = [System.Convert]::FromBase64String(`$EncodedText)"
Add-Content $fileOut "[System.IO.File]::WriteAllBytes(`'$verificationFile`', `$ByteArray)"

Write-Host
Write-Host "[$scriptName] Execute scipt ($fileOut) to recreate input file as $verificationFile"
executeExpression "./$fileOut"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
