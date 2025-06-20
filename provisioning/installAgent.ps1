# Doadload and extract the agent software, do not install the agent
# . { iwr -useb https://raw.githubusercontent.com/cdaf/windows/refs/heads/master/provisioning/installAgent.ps1 } | iex

# Download and install to the default agent pool
# iex "& { $(iwr -useb https://raw.githubusercontent.com/cdaf/windows/refs/heads/master/provisioning/installAgent.ps1) } 'https://dev.azure.com' 'XXXXXXXX'"

Param (
	[string]$url,
	[string]$pat,
	[string]$pool,
	[string]$agentName,
	[string]$serviceAccount,
	[string]$servicePassword,
	[string]$deploymentgroup,
	[string]$projectname,
	[string]$mediaDirectory,
	[string]$version
)

cmd /c "exit 0"
$scriptName = 'installAgent.ps1'
$error.clear()

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
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
function mask ($value) {
	return (Get-FileHash -InputStream $([IO.MemoryStream]::new([byte[]][char[]]$value)) -Algorithm MD5).Hash
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ( $url ) {
	Write-Host "[$scriptName] url             : $url"
} else {
	Write-Host "[$scriptName] url             : (not supplied, will just extract the agent software)"
}
if ( $pat ) {
	Write-Host "[$scriptName] pat             : $(mask $pat) (MD5 mask)"
} else {
	Write-Host "[$scriptName] pat             : (not supplied)"
}
if ( $pool ) {
	if ( $pool -match '@' ) {
		Write-Host "[$scriptName] pool            : $pool (contains '@' so will treat as Project@Deployment Group)"
	} else {
		Write-Host "[$scriptName] pool            : $pool (use pool name with '@' for Project@Deployment Group)"
	}
} else {
	$pool = 'default'
	if ( $pool -match '@' ) {
		Write-Host "[$scriptName] pool            : $pool (default, contains '@' so will treat as Project@Deployment Group)"
	} else {
		Write-Host "[$scriptName] pool            : $pool (default, use pool name with '@' for Project@Deployment Group)"
	}
}
if ( $agentName ) {
	Write-Host "[$scriptName] agentName       : $agentName"
} else {
	$agentName = "$env:COMPUTERNAME" 
	Write-Host "[$scriptName] agentName       : $agentName (not supplied, set to default)"
}

if ( $serviceAccount ) {
	Write-Host "[$scriptName] serviceAccount  : $serviceAccount"
} else {
	Write-Host "[$scriptName] serviceAccount  : (not supplied)"
}
if ( $servicePassword ) {
	Write-Host "[$scriptName] servicePassword : $(mask $servicePassword) (MD5 mask)"
} else {
	Write-Host "[$scriptName] servicePassword : (not supplied)"
}

if ( $deploymentgroup ) {
	Write-Host "[$scriptName] deploymentgroup : $deploymentgroup"
	Write-Host "[$scriptName] projectname     : $projectname"
} else {
	if ( $pool -match '@' ) {
		$projectname, $deploymentgroup = $pool.Split('@')
		Write-Host "[$scriptName] deploymentgroup : $deploymentgroup"
		Write-Host "[$scriptName] projectname     : $projectname"
	}
}

if ( $mediaDirectory ) {
	Write-Host "[$scriptName] mediaDirectory  : $mediaDirectory"
} else {
	$mediaDirectory = "$env:TEMP"
	Write-Host "[$scriptName] mediaDirectory  : $mediaDirectory (not supplied, set to default)"
}

if ( $version ) {
	Write-Host "[$scriptName] version         : $version"
} else {
	# from https://github.com/microsoft/azure-pipelines-agent/issues/3522
	$version = ((Invoke-RestMethod ((Invoke-RestMethod "https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest").assets_url)).browser_download_url).split('/')[-2].TrimStart('v')
	Write-Host "[$scriptName] version         : $version"
}

$fullpath = 'C:\agent\config.cmd'
$workspace = $(Get-Location)

executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
$mediaFileName = "vsts-agent-win-x64-${version}.zip"

if (Test-Path "${mediaDirectory}\${mediaFileName}") {
	Write-Host "[$scriptName] Media ${mediaDirectory}\${mediaFileName} exists"
} else {
	Write-Host "[$scriptName] Download VSTS Agent (using TLS 1.1 or 1.2)"
	if (Test-Path $mediaDirectory) {
		Write-Host "[$scriptName] Media Directory $mediaDirectory exists"
	} else {
		executeExpression "Write-Host `$(mkdir $mediaDirectory)"
	}
	executeExpression "curl.exe -fsSL https://download.agent.dev.azure.com/agent/${version}/${mediaFileName} -o '${mediaDirectory}\${mediaFileName}'"
}

Write-Host "`nExtract using default instructions from Microsoft"
if (Test-Path "C:\agent") {
	executeExpression 'Remove-Item "C:\agent\**" -Recurse -Force'
} else {
	executeExpression 'Write-Host $(mkdir C:\agent)'
}

executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory(`"$mediaDirectory\$mediaFileName`", `"C:\agent`")"

if ( $url ) {
	$argList = "--unattended --url $url"
	if ( $deploymentgroup ) {
		$argList += " --deploymentgroup --deploymentgroupname `"$deploymentgroup`" --projectname `"$projectname`""
	} else {
		$argList += " --pool `"$pool`""
	}
	if ( $env:http_proxy ) {
		$argList += " --proxyurl `"$env:http_proxy`""
	}

	$argList += " --auth PAT"

	Write-Host "`nUnattend configuration for VSTS with PAT authentication"
	if ( $serviceAccount.StartsWith('.\')) { 
		$serviceAccount = $serviceAccount.Substring(2) # Remove the .\ prefix
	}

	if ( $serviceAccount ) {
		$printList = "$argList --token `$pat --agent `"$agentName`" --replace --runasservice --windowslogonaccount `"$serviceAccount`" --windowslogonpassword `"`$servicePassword`""
		$argList += " --token $pat --agent `"$agentName`" --replace --runasservice --windowslogonaccount `"$serviceAccount`" --windowslogonpassword `"$servicePassword`""
	} else {
		$printList = "$argList --token `$pat --agent `"$agentName`" --replace"
		$argList += " --token $pat --agent `"$agentName`" --replace"
	}

	executeExpression "cd C:\agent"
	Write-Host "[$scriptName] Start-Process $fullpath -ArgumentList $printList -PassThru -Wait -NoNewWindow"
	$proc = Start-Process $fullpath -ArgumentList $argList -PassThru -Wait -NoNewWindow
	if ( $proc.ExitCode -ne 0 ) {
		Write-Host "`n[$scriptName] Error occured, listing last 40 lines of log $((Get-ChildItem C:\agent\_diag)[0].FullName)`n"
		Get-Content (Get-ChildItem C:\agent\_diag)[0].FullName -tail 40
		Write-Host "`n[$scriptName] Install Failed! Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
	    exit $proc.ExitCode
	}

	if ( $serviceAccount ) {
        $agentService = get-service vstsagent*
        if ( $agentService ) {
        	Write-Host "[$scriptName] Set the service to delayed start"
        	executeExpression "sc.exe config $($agentService.name) start= delayed-auto"
        	executeExpression "Start-Service $($agentService.name)"
        } else {
        	Write-Host "[$scriptName] Service not found! Exiting with exit code 3345"
        	exit 3345
    	}
    } else {
    	Write-Host "`n[$scriptName] Service Account not supplied will not attempt to start`n"
    }

} else {
	Write-Host "`n[$scriptName] URL not supplied. Agent software extracted to C:\agent`n"
}

executeExpression "cd $workspace"

Write-Host "`n[$scriptName] ---------- stop -----------`n"
exit 0