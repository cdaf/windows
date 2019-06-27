Param (
  [string]$uri,
  [string]$token,
  [string]$name,
  [string]$tags,
  [string]$executor,
  [string]$serviceAccount,
  [string]$saPassword,
  [string]$tlsCAFile,
  [string]$mediaDirectory
)
$scriptName = 'installRunner.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

cmd /c "exit 0"

Write-Host "`n[$scriptName] Refer to https://docs.gitlab.com/runner/install/windows.html"
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

if ( $tags ) {
	Write-Host "[$scriptName] tags           : $tags"
} else {
	$tags = "$env:COMPUTERNAME"
	Write-Host "[$scriptName] tags           : $tags (not supplied, set to default)"
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
	$mediaDirectory = 'C:\.provision'
	Write-Host "[$scriptName] mediaDirectory : $mediaDirectory (not supplied, set to default)"
}

if ( $version ) {
	Write-Host "[$scriptName] version        : $version"
} else {
	Write-Host "[$scriptName] version        : (not supplied, will use latest)"
}

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
		} else {
			if ( $version ) {
				Write-Host "[$scriptName] Download version $version"
				executeExpression "(New-Object System.Net.WebClient).DownloadFile('https://gitlab-runner-downloads.s3.amazonaws.com/v${version}/binaries/gitlab-runner-windows-amd64.exe', '$fullpath')"
			} else {
				executeExpression "(New-Object System.Net.WebClient).DownloadFile('https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-windows-amd64.exe', '$fullpath')"
			}
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
	
	$printList = "--debug register --non-interactive --url $uri --registration-token `$token --name $name --tag-list '$tags' --executor $executor --locked=false --shell powershell"
	$argList = "--debug register --non-interactive --url $uri --registration-token $token --name $name --tag-list '$tags' --executor $executor --locked=false --shell powershell"
	
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
				sleep $wait
				$wait = $wait + $wait
			}
		}
    }
	
	$arguments = 'install'
	if ( $serviceAccount ) {
		$arguments = $arguments + " --user $serviceAccount --password"
		Write-Host "[$scriptName] Start-Process gitlab-runner -PassThru -Wait -NoNewWindow -ArgumentList `"$arguments `$saPassword`""
	} else {
		Write-Host "[$scriptName] Start-Process gitlab-runner -PassThru -Wait -NoNewWindow -ArgumentList `"$arguments`""
	}
	
	if ( $saPassword ) {
		$arguments = $arguments + " $saPassword"
	}
	
	$proc = Start-Process gitlab-runner -PassThru -Wait -NoNewWindow -ArgumentList $arguments
	if ( $proc.ExitCode -ne 0 ) {
		Write-Host "`n[$scriptName] Install Failed! Exit with `$LASTEXITCODE $($proc.ExitCode)`n"
	    exit $proc.ExitCode
	}
	
	Write-Host "[$scriptName] Start Service using commandlet as gitlab-runner start can fail silently"
	executeExpression "Start-Service gitlab-runner"

} else {
	Write-Host "[$scriptName] URI not supplied so registration not attempted, register using :"
	Write-Host "[$scriptName]   gitlab-runner --debug register"
}

Write-Host "`n[$scriptName] ---------- stop -----------`n"
exit 0