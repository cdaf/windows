
# Download environment properties files from an external repository

Write-Host
Write-Host "[getEnvRepo.ps1] ---------- start ----------"
Write-Host

if ( $args[0] ) {
	$username = $args[0]
	Write-Host "[getEnvRepo.ps1] username         : $username"
} else {
	Write-Host "[getEnvRepo.ps1] Username not passed!"; exit 1
}

if ( $args[1] ) {
	$userpass = $args[1]
	Write-Host "[getEnvRepo.ps1] userpass         : **************"
} else {
	Write-Host "[getEnvRepo.ps1] userpass not passed!"; exit 2
}

if ( $args[2] ) {
	$externalCM = $args[2]
	Write-Host "[getEnvRepo.ps1] externalCM       : $externalCM"
} else {
	Write-Host "[getEnvRepo.ps1] externalCM not passed!"; exit 3
}

if ( $args[3] ) {
	$ENVIRONMENT = $args[3]
	Write-Host "[getEnvRepo.ps1] ENVIRONMENT      : $ENVIRONMENT"
} else {
	Write-Host "[getEnvRepo.ps1] ENVIRONMENT not passed!"; exit 3
}

Write-Host

$pair = "$($username):$($userpass)"
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$basicAuthValue = "Basic $encodedCreds"
$Headers = @{
    Authorization = $basicAuthValue
}

# If working on domain, try no-auth proxy server
if ( $env:userdnsdomain ) {
	$webRequestProxy = '-Proxy http://svn01.datacom.co.nz:5865'
	$curlProxy = '--proxy http://svn01.datacom.co.nz:5865'
}

# If the externalCM already includes a forward slash, it should still work even with two forward slashes
$outFile = $ENVIRONMENT + '.zip'
$uri = $externalCM + '/' + $outFile 
$expression = "Invoke-WebRequest -uri $uri -Headers `$Headers -OutFile $outFile $webRequestProxy"
Write-Host "  $expression"
try {
    Invoke-Expression $expression
    if(!$?) { 
    	Write-Host "  RemotePowershell WebRequest failed" -ForegroundColor Red
    	exit 210
	}
} catch {
	Write-Host "  RemotePowershell WebRequest exception, $_" -ForegroundColor Red
	exit 211
}

Write-Host
Write-Host "[getEnvRepo.ps1] Extract and replace local properties with the properties from the repository"
Write-Host "[getEnvRepo.ps1]   & 7za.exe x .\$ENVIRONMENT.zip -y"
& 7za.exe x .\$ENVIRONMENT.zip -y
$exitcode = $LASTEXITCODE
if ( $exitcode -gt 0 ) {
    write-host
    write-host "[getEnvRepo.ps1] $taskName failed!" -ForegroundColor Red
    write-host
    write-host "     Returning errorlevel ($exitcode) to DOS" -ForegroundColor Magenta
    write-host
    $host.SetShouldExit($exitcode)
    exit
}
