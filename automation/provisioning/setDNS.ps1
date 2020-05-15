Param (
	[string]$ipList,
	[string]$prepend,
	[string]$domainTest
)

cmd /c "exit 0"
$Error.Clear()

function executeRetry ($expression) {
	$exitCode = 1
	$wait = 10
	$retryMax = 5
	$retryCount = 0
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "[$retryCount] $expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?" -ForegroundColor Red; $exitCode = 1 }
		} catch { Write-Host "[$scriptName] $_" -ForegroundColor Red; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] Warning, message in `$error[0] = $error" -ForegroundColor Yellow; $error.clear() } # do not treat messages in error array as failure
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { $exitCode = $LASTEXITCODE; Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red; cmd /c "exit 0" }
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with `$LASTEXITCODE = $exitCode.`n"
				exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
				Start-Sleep $wait
			}
		}
    }
}

$scriptName = 'setDNS.ps1'
Write-Host "`n[$scriptName] ---------- start ----------"
if ($ipList) {
    Write-Host "[$scriptName] ipList     : $ipList (can pass space or comma separated list, or FQDN)"
} else {
    Write-Host "[$scriptName] ipList no supplied"; exit 100
}

if ($prepend) {
    Write-Host "[$scriptName] prepend    : $prepend"
} else {
	Write-Host "[$scriptName] prepend    : (net set, will replace)"
}

if ($domainTest) {
    Write-Host "[$scriptName] domainTest : $domainTest"
} else {
	Write-Host "[$scriptName] domainTest : (net set)"
}

if (!(($ipList -like '*,*') -or ($ipList -like '* *'))) { 
	$stringTest = $ipList.Split('.')
	$isFQDN = foreach ($item in $stringTest) { if (! ( $item -match "^\d+$" )) { Write-Output $item } }
	if ( $isFQDN ) {
		$ipList = ([System.Net.Dns]::GetHostAddresses($ipList))[0].IPAddressToString
		Write-Host "[$scriptName] Converted from FQDN to $ipList"
	}
}

Write-Host "[$scriptName] DNS List Before"
foreach ($interface in (Get-DnsClient -InterfaceAlias 'Ethernet*')) {
	Write-Host "$($interface.InterfaceAlias)[$($interface.InterfaceIndex)] $((Get-DnsClientServerAddress -InterfaceIndex $interface.InterfaceIndex).ServerAddresses)"
}

Write-Host "[$scriptName] Update and list the interface setttings"
foreach ($interface in (Get-DnsClient -InterfaceAlias 'Ethernet*')) {

	if ($prepend) {
		$ipList = "${ipList},$((Get-DnsClientServerAddress -AddressFamily 'IPv4' -InterfaceIndex $interface.InterfaceIndex).ServerAddresses)"
		Write-Host "[$scriptName] Prepended list $ipList (excludes IPv6)"
	}

	Set-DnsClientServerAddress -InterfaceIndex $interface.InterfaceIndex -ServerAddresses ($ipList)
	Write-Host "  InterfaceAlias           : $($interface.InterfaceAlias)"
	Write-Host "  InterfaceIndex           : $($interface.InterfaceIndex)"
	Write-Host "  ConnectionSpecificSuffix : $($interface.ServerAddresses)"
}

Write-Host "[$scriptName] DNS List After"
foreach ($interface in (Get-DnsClient -InterfaceAlias 'Ethernet*')) {
	Write-Host "$($interface.InterfaceAlias)[$($interface.InterfaceIndex)] $((Get-DnsClientServerAddress -InterfaceIndex $interface.InterfaceIndex).ServerAddresses)"
}

if ($domainTest) {
	$netBIOS = $domainTest.Split('.')[0]
	executeRetry "nltest /dsgetdc:$netBIOS /force"
	executeRetry "nltest /dsgetdc:$domainTest /force"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
