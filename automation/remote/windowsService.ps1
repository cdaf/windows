Param (
  [string]$serviceName,
  [string]$binpath,
  [string]$start,
  [string]$windowsServiceLocalAdmin,
  [string]$windowsServiceLocalAdminPassword

)

function executeRetry ($expression) {
	$wait = 10
	$retryMax = 10
	$retryCount = 0
	$exitCode = 1 # Any value other than 0 to enter the loop
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "[$scriptName][$retryCount] $expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
		} catch { echo $_.Exception|format-list -force; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; $exitCode = 3 }
		if ( $LASTEXITCODE -eq 1060 ) { cmd /c "exit 0" } # 10600 is a normal exit, use date to clear LASTEXITCODE
		if ( $LASTEXITCODE -eq 1073 )  { cmd /c "exit 0" } # 1073 is normal error  The specified service already exists
	    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; $exitCode = $LASTEXITCODE }
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, exiting with code $exitCode"; exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
				sleep $wait
			}
		}
    }
}

$scriptName = 'windowsService.ps1'
Write-Host "`n[$scriptName] ---------- start ----------"
if ($serviceName) {
    Write-Host "[$scriptName] serviceName : $serviceName"
} else {
    Write-Host "[$scriptName] serviceName not passed, exit with LASTEXITCODE 564"; exit 564
}
if ($windowsServiceLocalAdmin) {
    Write-Host "[$scriptName] windowsServiceLocalAdmin : $windowsServiceLocalAdmin"
} else {
    Write-Host "[$scriptName] windowsServiceLocalAdminPassword not passed"
}
if ($windowsServiceLocalAdminPassword) {
    Write-Host "[$scriptName] windowsServiceLocalAdminPassword : `$windowsServiceLocalAdminPassword"
} else {
    Write-Host "[$scriptName] windowsServiceLocalAdminPassword not passed"
}

if ($binpath) {
    Write-Host "[$scriptName] binpath     : $binpath"
	if ($start) {
	    Write-Host "[$scriptName] start       : $start"
	} else {
		$start = 'yes'
	    Write-Host "[$scriptName] start       : $start (default)"
	}
} else {
    Write-Host "[$scriptName] binpath not passed, delete service"
}

if ($binpath) {

    Write-Host "[$scriptName] sc.exe create $serviceName displayname= `"$binpath`" binpath= `"$binpath`" start= auto"
	sc.exe create $serviceName displayname= "$binpath" binpath= "$binpath" start= auto
	
	if ( $windowsServiceLocalAdmin ){
		sc.exe config $serviceName obj= $windowsServiceLocalAdmin password= $windowsServiceLocalAdminPassword
	}
	if ( $start -eq 'yes' ) {
		executeRetry "Start-Service $serviceName"
	} else {
	    Write-Host "[$scriptName] Start set to $start, so not attempt not executing Start-Service $serviceName"
	}
	
} else {

    Write-Host "[$scriptName] sc.exe GetDisplayName $serviceName"
	$exists = $(sc.exe GetDisplayName $serviceName)
	$exists
	if ( $exists -like '*SUCCESS*' ) { 
		executeRetry "Stop-Service $serviceName"
	    Write-Host "[$scriptName] sc.exe delete $serviceName"
		sc.exe delete $serviceName

	} else {
	
	    Write-Host "[$scriptName] $serviceName not installed, no further action required."
	}
} 

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0