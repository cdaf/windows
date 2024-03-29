# Usage examples

# Windows 2016
# [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls11,Tls12'

# Install Agent, register to "Default" Pool and install docker
# curl.exe -O https://raw.githubusercontent.com/cdaf/windows/master/bootstrap-vsts.ps1
# ./bootstrap-vsts.ps1 https://dev.azure.com/<your-org> <pool-manage-PAT>

# Install Agent, register to "windows-hosts" Pool and do not install docker
# curl.exe -O https://raw.githubusercontent.com/cdaf/windows/master/bootstrap-vsts.ps1
# ./bootstrap-vsts.ps1 https://dev.azure.com/<your-org> <pool-manage-PAT> -vstsPool "windows-hosts" -docker "no"

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

cmd /c "exit 0" # ensure LASTEXITCODE is 0
$error.clear()

function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1112 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red ; $error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE, $error[] = $error`n" -ForegroundColor Yellow
				$error.clear()
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName][WARN] $Error array populated but LASTEXITCODE not set, $error[] = $error`n" -ForegroundColor Yellow
			$error.clear()
		}
	}
}

$scriptName = 'bootstrap-vsts.ps1'

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
		$env:AGENT_SA_PASSWORD = -join ((65..90) + (97..122) + (33) + (35) + (43) + (45..46) + (58..64) | Get-Random -Count 30 | ForEach-Object {[char]$_})
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

Write-Host "[$scriptName] pwd                    : $(Get-Location)"
Write-Host "[$scriptName] whoami                 : $(whoami)"

$server = Get-ScheduledTask -TaskName 'ServerManager' -erroraction 'silentlycontinue'
if ( $server ) {
	executeExpression "Get-ScheduledTask -TaskName 'ServerManager' | Disable-ScheduledTask -Verbose"
} else {
	Write-Host "[$scriptName] Scheduled task ServerManager not installed, disable not required."
}

if ( Test-Path ".\automation\CDAF.windows") {
	Write-Host "[$scriptName] Use existing Continuous Delivery Automation Framework in ./automation"
} else {
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
		executeExpression "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls11,Tls12'"
		executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$PWD\$zipFile')"
		executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
		executeExpression '[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$zipfile", "$PWD")'
		executeExpression 'mv windows-master\automation .'
	}
}

executeExpression 'cat .\automation\CDAF.windows'
executeExpression '.\automation\provisioning\runner.bat .\automation\remote\capabilities.ps1'

if ($personalAccessToken) {

	if ( $agentSAPassword ) {
		executeExpression "./automation/provisioning/newUser.ps1 $vstsSA `$agentSAPassword -passwordExpires 'no'"
		executeExpression "./automation/provisioning/addUserToLocalGroup.ps1 Administrators '$vstsSA'"
		executeExpression "./automation/provisioning/setServiceLogon.ps1 '$vstsSA'"
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

Write-Host "`n[$scriptName] ---------- stop ----------"
