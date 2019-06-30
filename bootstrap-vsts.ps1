Param (
	[string]$agentSAPassword,
	[string]$vstsURL,
	[string]$personalAccessToken,
	[string]$agentName,
	[string]$vstsPackageAccessToken,
	[string]$vstsPool,
	[string]$vstsSA,
	[string]$stable
)

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

$scriptName = 'bootstrap-vsts.ps1'
cmd /c "exit 0" # ensure LASTEXITCODE is 0

Write-Host "`n[$scriptName] ---------- start ----------"
if ($agentSAPassword) {
    Write-Host "[$scriptName] agentSAPassword        : `$agentSAPassword"
} else {
    Write-Host "[$scriptName] agentSAPassword        : (not supplied, will install as inbuilt acocunt)"
}

if ($vstsURL) {
    Write-Host "[$scriptName] vstsURL                : $vstsURL"
} else {
	if ($personalAccessToken) {
	    Write-Host "[$scriptName] vstsURL not supplied, exit with error 7644"; exit 7644
    } else {
	    Write-Host "[$scriptName] vstsURL                : (not supplied and not required as PAT is not supplied)"
	}
}

if ($personalAccessToken) {
    Write-Host "[$scriptName] personalAccessToken    : `$personalAccessToken"
} else {
    Write-Host "[$scriptName] personalAccessToken    : (not supplied, will install VSTS agent but not attempt to register)"
}

if ($agentName) {
    Write-Host "[$scriptName] agentName              : $agentName"
} else {
	$agentName = 'VSTS-AGENT'
    Write-Host "[$scriptName] agentName              : $agentName (default)"
}

if ($vstsPackageAccessToken) {
    Write-Host "[$scriptName] vstsPackageAccessToken : `$vstsPackageAccessToken"
} else {
    Write-Host "[$scriptName] vstsPackageAccessToken : (not supplied)"
}

if ($vstsPool) {
    Write-Host "[$scriptName] vstsPool               : $vstsPool"
} else {
	$vstsPool = 'Default'
    Write-Host "[$scriptName] vstsPool               : $vstsPool (not supplied, set to default)"
}

if ($vstsSA) {
    Write-Host "[$scriptName] vstsSA                 : $vstsSA"
} else {
	$vstsSA = '.\vsts-agent-sa'
    Write-Host "[$scriptName] vstsSA                 : $vstsSA (not supplied, set to default)"
}

if ($stable) {
    Write-Host "[$scriptName] stable                 : $stable"
} else {
	$stable = 'no'
    Write-Host "[$scriptName] stable                 : $stable (not supplied, set to default)"
}

Write-Host "[$scriptName] pwd                    : $(pwd)"
Write-Host "[$scriptName] whoami                 : $(whoami)"

if ( $stable -eq 'yes' ) { 
	Write-Host "[$scriptName] Download Continuous Delivery Automation Framework"
	Write-Host "[$scriptName] `$zipFile = 'WU-CDAF.zip'"
	$zipFile = 'WU-CDAF.zip'
	Write-Host "[$scriptName] `$url = `"http://cdaf.io/static/app/downloads/$zipFile`""
	$url = "http://cdaf.io/static/app/downloads/$zipFile"
	executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$PWD\$zipFile')"
	executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
	executeExpression '[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$zipfile", "$PWD")'
} else {
	Write-Host "[$scriptName] Get latest CDAF from GitHub"
	Write-Host "[$scriptName] `$zipFile = 'windows-master.zip'"
	$zipFile = 'windows-master.zip'
	Write-Host "[$scriptName] `$url = `"https://codeload.github.com/cdaf/windows/zip/master`""
	$url = "https://codeload.github.com/cdaf/windows/zip/master"
	$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
	executeExpression '[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols'
	executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$PWD\$zipFile')"
	executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
	executeExpression '[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$zipfile", "$PWD")'
	executeExpression 'mv windows-master\automation .'
}

executeExpression 'cat .\automation\CDAF.windows'
executeExpression '.\automation\provisioning\runner.bat .\automation\remote\capabilities.ps1'

if ($personalAccessToken) {

	if ( $agentSAPassword ) {
		executeExpression './automation/provisioning/newUser.ps1 $vstsSA $agentSAPassword -passwordExpires no'
		executeExpression './automation/provisioning/addUserToLocalGroup.ps1 Administrators $vstsSA'
		executeExpression "./automation/provisioning/InstallAgent.ps1 $vstsURL `$personalAccessToken $vstsPool $agentName $vstsSA `$agentSAPassword "
	} else {
		executeExpression "./automation/provisioning/InstallAgent.ps1 $vstsURL `$personalAccessToken $vstsPool $agentName"
	}

} else {

	Write-Host "[$scriptName] VSTS Personal Access Token (personalAccessToken) not passed, so just extract software"
	executeExpression "./automation/provisioning/InstallAgent.ps1"

}

if ($vstsPackageAccessToken) {
    Write-Host "[$scriptName] Store vstsPackageAccessToken at machine level for subsequent configuration by the VSTS agent service account"
	executeExpression "Add-Content /packagePAT `"`$vstsPackageAccessToken`""
}

Write-Host "`n[$scriptName] ---------- stop ----------"
