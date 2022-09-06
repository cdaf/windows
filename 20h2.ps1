#  . { iwr -useb https://raw.githubusercontent.com/cdaf/windows/master/20h2.ps1 } | iex
# iwr -useb https://raw.githubusercontent.com/cdaf/windows/master/20h2.ps1 -o 20h2.ps1
# .\20h2.ps1 hyperv <smbpassword>
# .\20h2.ps1 virtualbox

Param (
	[string]$virtualisation,
	[string]$vagrantPass
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
			if ( $LASTEXITCODE -ne 3010 ) {
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

function MD5MSK ($value) {
	(Get-FileHash -InputStream $([IO.MemoryStream]::new([byte[]][char[]]$value)) -Algorithm MD5).Hash
}

$scriptName = 'dev.ps1'

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

if ( $env:http_proxy ) {
    executeExpression "[system.net.webrequest]::defaultwebproxy = New-Object system.net.webproxy('$env:http_proxy')"
} else {
    executeExpression '(New-Object System.Net.WebClient).Proxy.Credentials =[System.Net.CredentialCache]::DefaultNetworkCredentials' 
}

executeExpression "cd ~"
executeExpression "set-executionpolicy unrestricted -Force"
executeExpression ". { iwr -useb http://cdaf.io/static/app/downloads/cdaf.ps1 } | iex"

if ( $virtualisation -eq 'hyperv' ) {

    executeExpression ".\automation\provisioning\setenv.ps1 VAGRANT_DEFAULT_PROVIDER hyperv"
    executeExpression ".\automation\provisioning\setenv.ps1 VAGRANT_SMB_USER $env:USERNAME"
    if ($vagrantPass) {
        executeExpression ".\automation\provisioning\setenv.ps1 VAGRANT_SMB_PASS $vagrantPass"
    }
 
    executeExpression "Dism /online /enable-feature /all /featurename:Microsoft-Hyper-V /NoRestart"
    executeExpression "Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart"
    executeExpression ".\automation\provisioning\base.ps1 'docker-desktop wsl2'"
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

    executeExpression ".\automation\provisioning\base.ps1 'adoptopenjdk11 maven eclipse'"
    executeExpression ".\automation\provisioning\base.ps1 'nuget.commandline' -verion 5.8.1" # 5.9 is broken
    executeExpression ".\automation\provisioning\base.ps1 'azure-cli visualstudio2022enterprise vscode dotnetcore-sdk'"

    executeExpression ".\automation\provisioning\base.ps1 'nano nodejs-lts python git svn vnc-viewer putty winscp postman'"
    executeExpression ".\automation\provisioning\base.ps1 'googlechrome' -checksum ignore" # Google does not provide a static download, so checksum can briefly fail on new releases

    executeExpression "Remove-Item -Recurse -Force automation"
    if ( Test-Path git ) {
        Write-Host "Git directory exists"
    } else {
        executeExpression  "mkdir git"
    }
    executeExpression "cd .\git\"
    executeExpression "git clone https://github.com/cdaf/windows.git"
    executeExpression "& ${env:USERPROFILE}\git\windows\automation\provisioning\addPath.ps1 ${env:USERPROFILE}\git\windows\automation\provisioning User"
    executeExpression "& ${env:USERPROFILE}\git\windows\automation\provisioning\addPath.ps1 ${env:USERPROFILE}\git\windows\automation User"

    $extensions = @("jmrog.vscode-nuget-package-manager")
    $extensions += "ms-vscode.PowerShell"
    $extensions += "pronto-4gl-vscode-lang.pronto-4gl-language-definition"
    $extensions += "ms-vscode-remote.remote-ssh"
    $extensions += "ms-vscode-remote.remote-wsl"
    $extensions += "marcostazi.VS-code-vagrantfile"
    $extensions += "msazurermtools.azurerm-vscode-tools"
    $extensions += "DotJoshJohnson.xml"
    $extensions += "ms-azuretools.vscode-docker"
    $extensions += "bmewburn.vscode-intelephense-client"
    $extensions += "puppet.puppet-vscode"
    $extensions += "vscoss.vscode-ansible"
    $extensions += "ms-python.python"
    foreach ($extension in $extensions) {
        executeExpression "code --install-extension $extension --force"
    }

}

Write-Host "`n[$scriptName] ---------- stop ----------"
