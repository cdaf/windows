Param (
  [string]$portNumber,
  [string]$displayName,
  [string]$protocol
)
cmd /c "exit 0"
$scriptName = 'openFirewallPort.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 10 }
	} catch { echo $_.Exception|format-list -force; exit 11 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 12 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($portNumber) {
    Write-Host "[$scriptName] portNumber  : $portNumber"
} else {
    Write-Host "[$scriptName] portNumber not supplied, exiting with code 100"; exit 100
}

if ($displayName) {
    Write-Host "[$scriptName] displayName : $displayName"
} else {
	$displayName = $portNumber
    Write-Host "[$scriptName] displayName : not supplied, default to Port Number ($displayName)"
}

if ($protocol) {
    Write-Host "[$scriptName] protocol : $protocol (choices are TCP or UDP)"
} else {
	$protocol = 'TCP'
    Write-Host "[$scriptName] protocol : $protocol (not supplied, set to default, choices are TCP or UDP)"
}

# if any zone (private|public|domain) is enabled, then apply rule
try {
	$firewallProfiles = get-netfirewallprofile -ErrorAction SilentlyContinue
} catch {
    Write-Host "[$scriptName] Firewall service not available, so no action attempted."
}
$firewallon = $false
foreach ($zone in $firewallProfiles) { if ( $zone.enabled ) { $firewallon = $zone.enabled }}
if ( $firewallon ) {
	executeExpression "New-NetFirewallRule -DisplayName '$displayName' -Direction Inbound –Protocol '$protocol' –LocalPort $portNumber -Action allow"
} else {
    Write-Host "[$scriptName] Firewall not enabled for private, public or domain so no action attempted."
}

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
