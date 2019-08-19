Param (
	[string]$aesKey,
	[string]$inputFile,
	[string]$encyptedFile
)

cmd /c "exit 0"

function exceptionExit { 
    param ($exitcode)
    write-host
    $host.SetShouldExit($exitCode)
    exit
}

function taskComplete { param ($taskName)
    write-host
    write-host "[$scriptName] Remote Task ($taskName) Successfull " -ForegroundColor Green
    write-host
}

$scriptName = 'encrypt.ps1'

Write-Host; Write-Host "[$scriptName] Create an encrypted file using AES key "; Write-Host
Write-Host "[$scriptName] ---------- start ----------"
if ($aesKey) {
    Write-Host "[$scriptName] aesKey : $aesKey"
} else {
    Write-Host "[$scriptName] aesKey : (not supplied, new key will be generated"
}

if ($KeyFile) {
    Write-Host "[$scriptName] KeyFile  : $targetHost"
} else {
    Write-Host "[$scriptName] KeyFile  : (not suppplied, key will be output to standard out)"
}

Write-Host "[$scriptName] Creating AES key with random data"
$Key = New-Object Byte[] 16   # You can use 16, 24, or 32 for AES
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)

if ($KeyFile) {
	$Key | out-file $KeyFile
}

Create a SecureString from encrypted password using the Key that encrypted it
byte[]]$Key = (52,114,35,179,55,90,163,246,117,161,195,233,75,138,8,127)

$stringKey = ""
foreach ($element in $key) { $stringKey += "-$element" }
$stringKey = $stringKey.Substring(1)

$encryptedFile = 
Get-Content .\build.tsk -Raw  | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString -key $Key | Out-File $PasswordFile

# Creating SecureString object and export SecureString as encrypted string to file
$Key = Get-Content $KeyFile
$Password = "Ducati906&" | ConvertTo-SecureString -AsPlainText -Force 
$PasswordFile = "C:\scripts\Password.txt"
$Password | ConvertFrom-SecureString -key $Key | Out-File $PasswordFile
$PasswordSecureString = (Get-Content $PasswordFile | ConvertTo-SecureString -Key $key)

# Use file contents as encrypted password and convert to SecureString using the Key that encrypted it.
Password = '76492d1116743f0423413b16050a5345MgB8AG4AMABwAG4AYQByAFAAdQBSADAAYwAwAHAASAB5AGIATgBkAFIATgBDAGcAPQA9AHwAMABlAGYANgBmADQAYgAzAGQAMQAyADEAZgBmADQAZABhADIAYwA2AGQAMAA1AGQAMQBhAGQANAAzADkAYQA4AGUAOAA3ADMANwA3ADAANQA1ADEAMQA3ADkAYwA1AGYAOABkADIANAA1AGMAZABiAGYAYQA5ADQAZQAxADAANQA='
PasswordSecureString = $Password | ConvertTo-SecureString -Key $key

#Creating PSCredential object
$Username = "cicd-tnz"
$Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $PasswordSecureString

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
