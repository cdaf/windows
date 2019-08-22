Param (
	[string]$inputFile,
	[string]$stringKeyIn,
	[string]$decryptedFile
)

cmd /c "exit 0"

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

$scriptName = 'decrypt.ps1'

Write-Host "`n[$scriptName] Decrypt an encrypted file using AES key "
Write-Host "`n[$scriptName] ---------- start ----------"
if ($inputFile) {
    Write-Host "[$scriptName] inputFile     : $inputFile"
} else {
    Write-Host "[$scriptName] inputFile not suppplied!"; exit 101
}

if ($stringKeyIn) {
    Write-Host "[$scriptName] stringKeyIn   : `$stringKeyIn (example format 29-240-88-121-33-64-150-226-136-160-144-115-127-74-74-30)"
} else {
    Write-Host "[$scriptName] stringKeyIn not suppplied! (example format 29-240-88-121-33-64-150-226-136-160-144-115-127-74-74-30)"; exit 102
}

if ($decryptedFile) {
    Write-Host "[$scriptName] decryptedFile : $decryptedFile"
} else {
	$decryptedFile = $inputFile
    Write-Host "[$scriptName] decryptedFile : (not suppplied, existing file will be replaced)"
}

$key = @()
$key = $stringKeyIn.Split('-')
$secureFileInMemory = Get-Content $inputFile | ConvertTo-SecureString -Key $key
[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureFileInMemory)) > $decryptedFile

Write-Host "`n[$scriptName] Descrypted to $decryptedFile`n"

Write-Host "`n[$scriptName] ---------- stop ----------"
