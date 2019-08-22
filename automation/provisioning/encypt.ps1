Param (
	[string]$inputFile,
	[string]$encryptedFile,
	[string]$stringKeyIn
)

cmd /c "exit 0"

$scriptName = 'encrypt.ps1'

Write-Host "`n[$scriptName] Create an encrypted file using AES key "
Write-Host "`n[$scriptName] ---------- start ----------"
if ($inputFile) {
    Write-Host "[$scriptName] inputFile     : $inputFile"
} else {
    Write-Host "[$scriptName] inputFile not suppplied!"; exit 101
}

if ($encryptedFile) {
    Write-Host "[$scriptName] encryptedFile : $encryptedFile"
} else {
	$encryptedFile = $inputFile
    Write-Host "[$scriptName] encryptedFile : (not suppplied, existing file will be replaced)"
}

if ($stringKeyIn) {
    Write-Host "[$scriptName] stringKeyIn   : `$stringKeyIn (example format 29-240-88-121-33-64-150-226-136-160-144-115-127-74-74-30)"
    $key = @()
    $key = $stringKeyIn.Split('-')
} else {
    Write-Host "[$scriptName] stringKeyIn   : (not supplied, new key will be generated, example format 29-240-88-121-33-64-150-226-136-160-144-115-127-74-74-30)"
	$Key = New-Object Byte[] 16   # You can use 16, 24, or 32 for AES
	[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
	$stringKeyOut = ""
	foreach ($element in $key) { $stringKeyOut += "-$element" }
	$stringKeyOut = $stringKeyOut.Substring(1)
}

Get-Content $inputFile -Raw  | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString -key $Key | Out-File $encryptedFile
if ( $stringKeyOut ) {
	$stringKeyOut
}
Write-Host "`n[$scriptName] ---------- stop ----------"
