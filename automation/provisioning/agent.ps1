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

$scriptName = 'agent.ps1'

Write-Host
Write-Host "[$scriptName] Create an encrypted password file (outfile) for the current user and test against address (targethost)"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$targetHost = $args[0]
if ($targetHost) {
    Write-Host "[$scriptName] Target Host : $targetHost"
} else {
    $targetHost = $(hostname)
    Write-Host "[$scriptName] Target Host not passed, default to local host ($targetHost)"
}

$userID = $args[1]
if ($userID) {
    Write-Host "[$scriptName] Target User : $userID"
} else {
    $userID = $(whoami)
    Write-Host "[$scriptName] Target Host not passed, default to current user ($userID)"
}

$outputFile = $args[2]
if ($outputFile) {
    Write-Host "[$scriptName] Output File : $outputFile"
} else {
    $outputFile = "$(hostname)-${targetHost}.crypt"
    Write-Host "[$scriptName] Output File not passed, default to $outputFile"
}

Write-Host
Write-Host "[$scriptName] Pipe password into an encrypted file, enter password : " -NoNewline
read-host -assecurestring | convertfrom-securestring | out-file $outputFile

Write-Host
Write-Host "[$scriptName] Read the password into a variable (don't print the content of this variable)"
$password = get-content $outputFile | convertto-securestring

Write-Host
Write-Host "[$scriptName] Create a credential object with the user ID and password"
$cred = New-Object System.Management.Automation.PSCredential ($userID, $password )
Write-Host
try {
	Invoke-Command -credential $cred -ComputerName $targetHost { Write-Host "Running as $(whoami) on $(hostname), test successful" }
	if(!$?){ exceptionExit 1 }
} catch { exceptionExit 2 }

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
