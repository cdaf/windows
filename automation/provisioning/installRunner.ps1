Param (
  [string]$uri,
  [string]$token,
  [string]$name,
  [string]$executor,
  [string]$serviceAccount,
  [string]$saPassword,
  [string]$tlsCAFile,
  [string]$mediaDirectory
)
$scriptName = 'installRunner.ps1'

# Runner registration tokens deprecated, along with "tag" and "lock" support from CLI
# Create a runner from UI, copy the token and run this script
# https://docs.gitlab.com/ee/security/token_overview.html#runner-authentication-tokens-also-called-runner-tokens

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
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE, $error[] =`n" -ForegroundColor Yellow
				$error
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName][WARN] $Error array populated but LASTEXITCODE not set, $error[] =`n" -ForegroundColor Yellow
			$error
		}
	}
}

cmd /c "exit 0"
$error.clear()

Write-Host "`n[$scriptName] ---------- start ----------"
$uri = $uri
if ( $uri ) {
	Write-Host "[$scriptName] uri            : $uri"
} else {
	Write-Host "[$scriptName] uri            : (not supplied, will just extract the agent software)"
}

if ( $token ) {
	Write-Host "[$scriptName] token          : `$token"
} else {
	Write-Host "[$scriptName] token          : (not supplied)"
}

if ( $name ) {
	Write-Host "[$scriptName] name           : $name"
} else {
	$name = "$env:COMPUTERNAME"
	Write-Host "[$scriptName] name           : $name (not supplied, set to default)"
}

if ( $executor ) {
	Write-Host "[$scriptName] executor       : $executor"
} else {
	$executor = 'shell'
	Write-Host "[$scriptName] executor       : $executor (not supplied, set to default)"
}

if ( $serviceAccount ) {
	Write-Host "[$scriptName] serviceAccount : $serviceAccount"
} else {
	Write-Host "[$scriptName] serviceAccount : (not supplied)"
}

if ( $saPassword ) {
	Write-Host "[$scriptName] saPassword     : `$saPassword"
} else {
	Write-Host "[$scriptName] saPassword     : (not supplied)"
}

if ( $tlsCAFile ) {
	Write-Host "[$scriptName] tlsCAFile      : $tlsCAFile"
} else {
	Write-Host "[$scriptName] tlsCAFile      : (not supplied)"
}

if ( $mediaDirectory ) {
	Write-Host "[$scriptName] mediaDirectory : $mediaDirectory"
} else {
	$mediaDirectory = "$env:TEMP"
	Write-Host "[$scriptName] mediaDirectory : $mediaDirectory (not supplied, set to default)"
}

if ( $version ) {
	Write-Host "[$scriptName] version        : $version"
} else {
	Write-Host "[$scriptName] version        : (not supplied, will use latest)"
}

executeExpression "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12"

$versionTest = cmd /c gitlab-runner --version 2`>`&1
if (!($versionTest -like '*not recognized*')) {
	$versionLine = $(foreach ($line in $versionTest) { Select-String  -InputObject $line -CaseSensitive "Version" })
	$arr = $versionLine -split ':'
	Write-Host "[$scriptName] gitlab-runner already installed, using version $($arr[1].replace(' ',''))"
} else {
	cmd /c "exit 0" # reset $LASTEXITCODE
	if (!( Test-Path "C:\GitLab-Runner" )) {
		Write-Host "[$scriptName] Create runtime directory $(mkdir C:\GitLab-Runner)"
		Write-Host "[$scriptName] Add C:\GitLab-Runner to PATH and reload path"
		[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\GitLab-Runner", [EnvironmentVariableTarget]::Machine)
		$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
	}
	$fullpath = $mediaDirectory + '\gitlab-runner-windows-amd64.exe'
	if ( Test-Path $fullpath ) {
		if ( $version ) {
			Write-Host "[$scriptName] Version specified, purge cache copy and download version"
			executeExpression "rm $fullpath"
			executeExpression "(New-Object System.Net.WebClient).DownloadFile('https://gitlab-runner-downloads.s3.amazonaws.com/v${version}/binaries/gitlab-runner-windows-amd64.exe', '$fullpath')"
		} 
	} else {
		if ( $version ) {
			Write-Host "[$scriptName] Download version $version"
			executeExpression "(New-Object System.Net.WebClient).DownloadFile('https://gitlab-runner-downloads.s3.amazonaws.com/v${version}/binaries/gitlab-runner-windows-amd64.exe', '$fullpath')"
		} else {
			executeExpression "(New-Object System.Net.WebClient).DownloadFile('https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-windows-amd64.exe', '$fullpath')"
		}
	}
	executeExpression "Copy-Item $fullpath 'C:\GitLab-Runner\gitlab-runner.exe'"

	$versionTest = cmd /c gitlab-runner --version 2`>`&1
	if ( $LASTEXITCODE -ne 0 ) {
		Write-Host "[$scriptName] GitLab Runner install failed!"; exit $LASTEXITCODE
	} else {
		$versionLine = $(foreach ($line in $versionTest) { Select-String  -InputObject $line -CaseSensitive "Version" })
		$arr = $versionLine -split ':'
		Write-Host "[$scriptName] gitlab-runner  : $($arr[1].replace(' ',''))"
	}
} 


if ( $uri ) {
	
	$printList = "--debug register --non-interactive --url $uri --token `$token --name $name --executor $executor --shell powershell"
	$argList = "--debug register --non-interactive --url $uri --token $token --name $name --executor $executor --shell powershell"
	
	if ( $tlsCAFile ) {
		$printList = $printList + " --tls-ca-file $tlsCAFile"
		$argList = $argList + " --tls-ca-file $tlsCAFile"
	}
	
	$exitCode = 1
	$wait = 10
	$retryMax = 5
	$retryCount = 0
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		Write-Host "[$scriptName] Start-Process gitlab-runner -PassThru -Wait -NoNewWindow -ArgumentList `"$printList`""
		$proc = Start-Process gitlab-runner -PassThru -Wait -NoNewWindow -ArgumentList $argList
	    $exitCode = $proc.ExitCode
		if ( $exitCode -ne 0 ) {
			Write-Host "`n[$scriptName] Registration Failed! Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with `$LASTEXITCODE = $exitCode.`n"
				exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
				Start-Sleep $wait
				$wait = $wait + $wait
			}
		}
    }
	
	$arguments = 'install'
	if ( $serviceAccount ) {
		$arguments += " --user '$serviceAccount' --password"
		executeExpression "gitlab-runner $arguments `"`$saPassword`""
	} else {
		executeExpression "gitlab-runner $arguments"
	}
	
	Write-Host "[$scriptName] Start Service using commandlet as gitlab-runner start can fail silently"
	executeExpression "Start-Service gitlab-runner"

} else {
	Write-Host "[$scriptName] URI not supplied so registration not attempted, register using :"
	Write-Host "[$scriptName]   gitlab-runner --debug register"
}

Write-Host "`n[$scriptName] ---------- stop -----------`n"
exit 0