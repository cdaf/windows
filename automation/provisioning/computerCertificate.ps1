Param (
  [string]$certificateName
)
# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	$LASTEXITCODE = 0
	Write-Host "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if ( $LASTEXITCODE -ne 0 ) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

$scriptName = 'computerCertificate.ps1'
Write-Host "`n[$scriptName] ---------- start ----------"
if ($certificateName) {
    Write-Host "[$scriptName] certificateName : $certificateName"
} else {
	$certificateName = 'localhost'
    Write-Host "[$scriptName] certificateName : $certificateName (not passed, set to default)"
}

$localThumbPrint = foreach ( $certificate in get-childitem "cert:\localmachine\my" ) { if ($certificate.DnsNameList -eq "$certificateName") { $certificate.Thumbprint}}
if ($localThumbPrint ) {
	Write-Host "`n[$scriptName] $certificateName certificate exists with thumbprint $localThumbPrint"
} else {
	$certificate = executeExpression "New-SelfSignedCertificate -certstorelocation cert:\localmachine\my -dnsname $certificateName"
	Write-Host "`n[$scriptName] Created self-signed certificate with thumbprint $($certificate.Thumbprint)"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0