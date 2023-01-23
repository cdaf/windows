# Install base development tools
#  . { iwr -useb https://raw.githubusercontent.com/cdaf/windows/master/22h2.ps1 } | iex

# Install Virtualisation choices
# iwr -useb https://raw.githubusercontent.com/cdaf/windows/master/22h2.ps1 -o 22h2.ps1
# .\22h2.ps1 hyperv or .\22h2.ps1 hyperv <smbpassword> or .\22h2.ps1 hyperv <smbpassword> <smbusername>
# .\22h2.ps1 virtualbox

Param (
	[string]$virtualisation,
	[string]$vagrantPass,
	[string]$vagrantUser
)

cmd /c "exit 0"
$Error.Clear()

# Consolidated Error processing function
function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Red
	} else {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Yellow
	}
	if ( $error ) {
		$i = 0
		foreach ( $item in $Error )
		{
			Write-Host "`$Error[$i] $item"
			$i++
		}
		$Error.clear()
	}
	if ( $env:CDAF_ERROR_DIAG ) {
		Write-Host "`n[$scriptName] Invoke custom diag `$env:CDAF_ERROR_DIAG = $env:CDAF_ERROR_DIAG`n"
		Invoke-Expression $env:CDAF_ERROR_DIAG
	}
	if ( $exitcode ) {
		Write-Host "`n[$scriptName] Exit with LASTEXITCODE = $exitcode`n" -ForegroundColor Red
		exit $exitcode
	}
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { ERRMSG "[TRAP] `$? = $?" 1211 }
	} catch {
		$message = $_.Exception.Message
		$_.Exception | format-list -force
		$_.Exception.StackTrace
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
			ERRMSG "[EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			if ( $LASTEXITCODE -eq 3010 ) {
				ERRMSG "[WARN] Pending Reboot, `$LASTEXITCODE is $LASTEXITCODE"
			} else {
				ERRMSG "[EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
			}
		} else {
			if ( $error ) {
				ERRMSG "[WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				ERRMSG "[WARN] `$LASTEXITCODE not set, but standard error populated"
	    	}
		}
	}
}

function executeCMD ($expression, $ignore) {
	$error.clear()
	Write-Host "[$(Get-Date)] $expression"
	try {
		cmd /c $expression
	    if(!$?) { ERRMSG "[TRAP] `$? = $?" $(if ( ! $ignore ) { 1211 }) }
	} catch {
		$message = $_.Exception.Message
		$_.Exception | format-list -force
		$_.Exception.StackTrace
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
			ERRMSG "[EXEC][EXCEPTION] $message" $(if ( ! $ignore ) { $LASTEXITCODE })
		} else {
			ERRMSG "[EXEC][EXCEPTION] $message" $(if ( ! $ignore ) { 1212 })
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			ERRMSG "[EXEC][EXIT] `$LASTEXITCODE is $LASTEXITCODE" $(if ( ! $ignore ) { $LASTEXITCODE })
		} else {
			if ( $error ) {
				ERRMSG "[EXEC][WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[EXEC][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" $(if ( ! $ignore ) { 1213 })
	    	} else {
				ERRMSG "[EXEC][WARN] `$LASTEXITCODE not set, but standard error populated"
	    	}
		}
	}
}

function MD5MSK ($value) {
	(Get-FileHash -InputStream $([IO.MemoryStream]::new([byte[]][char[]]$value)) -Algorithm MD5).Hash
}

$scriptName = '22h2.ps1'

Write-Host "`n[$scriptName] ---------- start ----------"
if ($virtualisation) {
    Write-Host "virtualisation : $virtualisation"
} else {
    Write-Host "virtualisation : (not specified, developer configuration)"
}
if ($vagrantPass) {
    Write-Host "vagrantPass    : $(MD5MSK $vagrantPass) (MD5 mask)"
} else {
    Write-Host "vagrantPass    : (not specified)"
}
if ($vagrantPass) {
    Write-Host "vagrantUSer    : $vagrantUser"
} else {
    Write-Host "vagrantPass    : (not specified, will use current user if password set)"
}

if ( $env:http_proxy ) {
    executeExpression "[system.net.webrequest]::defaultwebproxy = New-Object system.net.webproxy('$env:http_proxy')"
} else {
    executeExpression '(New-Object System.Net.WebClient).Proxy.Credentials =[System.Net.CredentialCache]::DefaultNetworkCredentials' 
}

executeExpression "cd ~"
Write-Host "set-executionpolicy unrestricted -Force"
set-executionpolicy unrestricted -Force

executeExpression ". { iwr -useb http://cdaf.io/static/app/downloads/cdaf.ps1 } | iex"

if ( $virtualisation -eq 'hyperv' ) {

    executeExpression ".\automation\provisioning\setenv.ps1 VAGRANT_DEFAULT_PROVIDER hyperv"
    if ($vagrantPass) {
        executeExpression ".\automation\provisioning\setenv.ps1 VAGRANT_SMB_PASS $vagrantPass"
        if ($vagrantUser) {
	    executeExpression ".\automation\provisioning\setenv.ps1 VAGRANT_SMB_USER $vagrantUser"
        } else {
	    executeExpression ".\automation\provisioning\setenv.ps1 VAGRANT_SMB_USER $env:USERNAME"
	}
    }
 
    executeExpression "Dism /online /enable-feature /all /featurename:Microsoft-Hyper-V /NoRestart"
    executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart"
    executeExpression ".\automation\provisioning\base.ps1 docker-desktop"
    executeExpression ".\automation\provisioning\base.ps1 wsl2"
    executeExpression ".\automation\provisioning\base.ps1 'vagrant' -autoReboot no"
    executeExpression  "Remove-Item -Recurse -Force automation"

    executeExpression "shutdown /r /t 0"

} elseif ( $virtualisation -eq 'virtualbox' ) {

    executeExpression "addHOSTS.ps1 172.16.17.90  cbe.mshome.net"
    executeExpression "addHOSTS.ps1 172.16.17.98  dc.mshome.net"
    executeExpression "addHOSTS.ps1 172.16.17.99  db.mshome.net"
    executeExpression "addHOSTS.ps1 172.16.17.100 agent.mshome.net"
    executeExpression "addHOSTS.ps1 172.16.17.100 build.mshome.net"
    executeExpression "addHOSTS.ps1 172.16.17.101 server-1.mshome.net"
    executeExpression "addHOSTS.ps1 172.16.17.102 server-2.mshome.net"
    executeExpression "addHOSTS.ps1 172.16.17.101 windows-1.mshome.net"
    executeExpression "addHOSTS.ps1 172.16.17.102 windows-2.mshome.net"
    executeExpression "addHOSTS.ps1 172.16.17.103 app.mshome.net"
 
    executeExpression ".\automation\provisioning\base.ps1 'virtualbox'"
    executeExpression ".\automation\provisioning\base.ps1 'vagrant' -autoReboot no"
    executeExpression  "Remove-Item -Recurse -Force automation"

    executeExpression "shutdown /r /t 0"
	
} else {

    executeExpression "Set-Service beep -StartupType disabled"
    executeExpression "Get-AppxPackage Microsoft.YourPhone -AllUsers | Remove-AppxPackage"
    executeExpression "(Get-WmiObject Win32_TerminalServiceSetting -Namespace root\cimv2\TerminalServices).SetAllowTsConnections(1,1) | Out-Null"
    executeExpression "(Get-WmiObject -Class 'Win32_TSGeneralSetting' -Namespace root\cimv2\TerminalServices -Filter `"TerminalName='RDP-tcp'`").SetUserAuthenticationRequired(0) | Out-Null"
    executeExpression "Get-NetFirewallRule -DisplayName `"Remote Desktop*`" | Set-NetFirewallRule -enabled true"

    executeExpression ".\automation\provisioning\base.ps1 'microsoft-openjdk11 maven eclipse'"

    executeExpression ".\automation\provisioning\base.ps1 nodejs-lts"
    executeExpression ".\automation\provisioning\base.ps1 python"

    executeExpression ".\automation\provisioning\base.ps1 'nuget.commandline' -verion 5.8.1" # 5.9 is broken
    executeExpression ".\automation\provisioning\base.ps1 visualstudio2022enterprise"
    executeExpression "curl.exe -fSL $env:CURL_OPT -O https://aka.ms/vs/17/release/vs_enterprise.exe"
    executeCMD "start /w vs_enterprise.exe --quiet --wait --norestart --nocache --noUpdateInstaller --noWeb --add Microsoft.VisualStudio.Workload.Azure --locale en-US"
    executeCMD "start /w vs_enterprise.exe --quiet --wait --norestart --nocache --noUpdateInstaller --noWeb --add Microsoft.VisualStudio.Workload.NetWeb --locale en-US"
    executeCMD "start /w vs_enterprise.exe --quiet --wait --norestart --nocache --noUpdateInstaller --noWeb --add Microsoft.VisualStudio.Workload.Node --locale en-US"
    executeCMD "start /w vs_enterprise.exe --quiet --wait --norestart --nocache --noUpdateInstaller --noWeb --add Microsoft.VisualStudio.Workload.Python --locale en-US"
    executeCMD "start /w vs_enterprise.exe --quiet --wait --norestart --nocache --noUpdateInstaller --noWeb --add Microsoft.Component.PythonTools.Web --locale en-US"

    executeExpression ".\automation\provisioning\base.ps1 azure-cli"
    executeExpression ".\automation\provisioning\base.ps1 dotnet-6.0-sdk"

    # Ensure NuGet is a source, by default it is not (ignore if already added)
    Write-Host "nuget sources add -Name NuGet.org -Source https://api.nuget.org/v3/index.json"
    nuget sources add -Name NuGet.org -Source https://api.nuget.org/v3/index.json
    
    executeExpression ".\automation\provisioning\base.ps1 'vswhere'" # Install this now that VS is installed

    executeExpression ".\automation\provisioning\base.ps1 nano"
    executeExpression ".\automation\provisioning\base.ps1 svn"
    executeExpression ".\automation\provisioning\base.ps1 vnc-viewer"
    executeExpression ".\automation\provisioning\base.ps1 putty"
    executeExpression ".\automation\provisioning\base.ps1 winscp"
    executeExpression ".\automation\provisioning\base.ps1 postman"

    executeExpression ".\automation\provisioning\base.ps1 git"
    executeExpression "git config --global core.autocrlf false"

    executeExpression ".\automation\provisioning\base.ps1 'googlechrome' -checksum ignore" # Google does not provide a static download, so checksum can briefly fail on new releases

    executeExpression ".\automation\provisioning\base.ps1 vscode"
    $extensions = @()
    $extensions += "42crunch.vscode-openapi"
    $extensions += "bierner.markdown-mermaid"
    $extensions += "bmewburn.vscode-intelephense-client"
    $extensions += "cweijan.vscode-mysql-client2"
    $extensions += "DotJoshJohnson.xml"
    $extensions += "hashicorp.terraform"
    $extensions += "hediet.vscode-drawio"
    $extensions += "jmrog.vscode-nuget-package-manager"
    $extensions += "marcostazi.VS-code-vagrantfile"
    $extensions += "ms-dotnettools.csharp"
    $extensions += "ms-azuretools.vscode-azurefunctions"
    $extensions += "ms-azuretools.vscode-azureresourcegroups"
    $extensions += "ms-azuretools.vscode-cosmosdb"
    $extensions += "ms-azuretools.vscode-docker"
    $extensions += "ms-python.python"
    $extensions += "ms-python.vscode-pylance"
    $extensions += "ms-toolsai.jupyter"
    $extensions += "ms-toolsai.vscode-ai"
    $extensions += "ms-toolsai.vscode-ai-remote"
    $extensions += "ms-vscode.azure-account"
    $extensions += "ms-vscode.powershell"
    $extensions += "ms-vscode-remote.remote-containers"
    $extensions += "ms-vscode-remote.remote-ssh"
    $extensions += "ms-vscode-remote.remote-wsl"
    $extensions += "msazurermtools.azurerm-vscode-tools"
    $extensions += "pronto-4gl-vscode-lang.pronto-4gl-language-definition"
    $extensions += "puppet.puppet-vscode"
    $extensions += "redhat.vscode-yaml"
    $extensions += "streetsidesoftware.code-spell-checker"
    $extensions += "vscoss.vscode-ansible"
    
    foreach ($extension in $extensions) {
        executeExpression "code --install-extension $extension --force"
    }

}

Write-Host "`n[$scriptName] List installed Chocolatey packages..."
executeExpression "choco list --localonly"

Write-Host "`n[$scriptName] ---------- stop ----------"
