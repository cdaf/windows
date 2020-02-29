Param (
	[string]$vstsURL,
	[string]$personalAccessToken,
	[string]$vstsSA,
	[string]$vstsPool,
	[string]$agentSAPassword,
	[string]$agentName,
	[string]$vstsPackageAccessToken,
	[string]$stable,
	[string]$docker,
	[string]$restart
)

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$(date)] $expression | Tee-Object -Append -FilePath '$env:temp\InstallAgent.log'"
	try {
		Invoke-Expression "$expression | Tee-Object -FilePath '$env:temp\InstallAgent.log'"
	    if(!$?) { Write-Host "[FAILURE][$scriptName] `$? = $?"; Write-Host "[$scriptName] See logs at $env:temp\InstallAgent.log"; exit 1 }
	} catch { echo $_.Exception|format-list -force; Write-Host "[$scriptName] See logs at $env:temp\InstallAgent.log"; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; Write-Host "[$scriptName] See logs at $env:temp\InstallAgent.log"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; Write-Host "[$scriptName] See logs at $env:temp\InstallAgent.log"; exit $LASTEXITCODE }
}

$scriptName = 'bootstrap-vsts.ps1'
cmd /c "exit 0" # ensure LASTEXITCODE is 0

Write-Host "`n[$scriptName] ---------- start ----------"
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

if ($vstsSA) {
    Write-Host "[$scriptName] vstsSA                 : $vstsSA"
} else {
	$vstsSA = '.\vsts-agent-sa'
    Write-Host "[$scriptName] vstsSA                 : $vstsSA (not supplied, set to default)"
}

if ($vstsPool) {
    Write-Host "[$scriptName] vstsPool               : $vstsPool"
} else {
	$vstsPool = 'Default'
    Write-Host "[$scriptName] vstsPool               : $vstsPool (not supplied, set to default)"
}

if ($agentSAPassword) {
    Write-Host "[$scriptName] agentSAPassword        : `$agentSAPassword"
} else {
	if ($vstsSA) {
		$env:AGENT_SA_PASSWORD = -join ((65..90) + (97..122) + (33) + (35) + (43) + (45..46) + (58..64) | Get-Random -Count 30 | % {[char]$_})
		$agentSAPassword = $env:AGENT_SA_PASSWORD
	    Write-Host "[$scriptName] agentSAPassword        : `$env:AGENT_SA_PASSWORD (not supplied but vstsSA set, so randomly generated)"
	} else {
	    Write-Host "[$scriptName] agentSAPassword        : (not supplied and vstsSA, will install as inbuilt account)"
	}
}

if ($agentName) {
    Write-Host "[$scriptName] agentName              : $agentName"
} else {
	$agentName = $env:COMPUTERNAME
    Write-Host "[$scriptName] agentName              : $agentName (default)"
}

if ($vstsPackageAccessToken) {
    Write-Host "[$scriptName] vstsPackageAccessToken : `$vstsPackageAccessToken"
} else {
    Write-Host "[$scriptName] vstsPackageAccessToken : (not supplied)"
}

if ($stable) {
    Write-Host "[$scriptName] stable                 : $stable"
} else {
	$stable = 'yes'
    Write-Host "[$scriptName] stable                 : $stable (not supplied, set to default)"
}

if ($docker) {
    Write-Host "[$scriptName] docker                 : $docker"
} else {
	$docker = 'yes'
    Write-Host "[$scriptName] docker                 : $docker (not supplied, set to default)"
}

if ($restart) {
    Write-Host "[$scriptName] restart                : $restart (only applies if docker install selected)"
} else {
	$restart = 'yes'
    Write-Host "[$scriptName] restart                : $restart (not supplied, set to default, only applies if docker install selected)"
}

Write-Host "[$scriptName] pwd                    : $(pwd)"
Write-Host "[$scriptName] whoami                 : $(whoami)"

$server = Get-ScheduledTask -TaskName 'ServerManager' -erroraction 'silentlycontinue'
if ( $server ) {
	executeExpression "Get-ScheduledTask -TaskName 'ServerManager' | Disable-ScheduledTask -Verbose"
} else {
	Write-Host "[$scriptName] Scheduled task ServerManager not installed, disable not required."
}

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

if ( $docker -eq 'yes' ) { 
	executeExpression "./automation/provisioning/InstallDocker.ps1 -restart $restart"
}

Write-Host "[$scriptName] See logs at $env:temp\InstallAgent.log"

Write-Host "`n[$scriptName] ---------- stop ----------"
