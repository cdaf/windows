Param (
	[string]$SOLUTION,
	[string]$BUILDNUMBER,
	[string]$REVISION,
	[string]$PROJECT,
	[string]$ENVIRONMENT,
	[string]$ACTION
)

$scriptName = 'build.ps1'
cmd /c "exit 0"

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

function executeRetry ($expression) {
	$exitCode = 1
	$wait = 10
	$retryMax = 5
	$retryCount = 0
	while (( $retryCount -le $retryMax ) -and ($exitCode -ne 0)) {
		$exitCode = 0
		$error.clear()
		Write-Host "[$scriptName][$retryCount] $expression"
		try {
			Invoke-Expression $expression
		    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $exitCode = 1 }
		} catch { Write-Host "[$scriptName] $_"; $exitCode = 2 }
	    if ( $error[0] ) { Write-Host "[$scriptName] Warning, message in `$error[0] = $error"; $error.clear() } # do not treat messages in error array as failure
	    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode "; $exitCode = $LASTEXITCODE }
	    if ($exitCode -ne 0) {
			if ($retryCount -ge $retryMax ) {
				Write-Host "[$scriptName] Retry maximum ($retryCount) reached, listing docker images and processes for diagnostics and exiting with `$LASTEXITCODE = $exitCode.`n"
				Write-Host "[$scriptName] docker images`n"
				docker images
				Write-Host "`n[$scriptName] docker ps`n"
				docker ps
				Write-Host "`n[$scriptName] docker-compose logs`n"
				docker-compose logs
				exit $exitCode
			} else {
				$retryCount += 1
				Write-Host "[$scriptName] Wait $wait seconds, then retry $retryCount of $retryMax"
				Write-Host "[$scriptName] docker-compose logs`n"
				docker-compose logs
				sleep $wait
			}
		}
    }
}

Write-Host "`n[$scriptName] ---------- start ----------`n"
Write-Host "[$scriptName]   SOLUTION    : $SOLUTION"
Write-Host "[$scriptName]   BUILDNUMBER : $BUILDNUMBER"
Write-Host "[$scriptName]   REVISION    : $REVISION"
Write-Host "[$scriptName]   PROJECT     : $PROJECT"
Write-Host "[$scriptName]   ENVIRONMENT : $ENVIRONMENT"
Write-Host "[$scriptName]   ACTION      : $ACTION"

# Properties file loader, all properties are instantiated as runtime variables and listed in the logs
write-host "The transform does not support relative paths, so the parent path must be resolved before invokation"
$parentPath = (Get-Item -Path "..\" -Verbose).FullName
..\autodeploy\remote\Transform.ps1 "$parentPath\autodeploy\solution\propertiesForLocalTasks\$ENVIRONMENT" | ForEach-Object { invoke-expression $_ }

<# Web Deploy Build Example

itemRemove *.zip
itemRemove "logs*"

if ( $ACTION -eq "clean" ) {

	Write-Host
	write-host "[$scriptName] Clean only." -ForegroundColor Blue
	
} else {

    write-host "[$scriptName] Web Deploy Build "
    
    $msbuild = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\msbuild.exe"
    $buildCommand = "& $msbuild $PROJECT.csproj '/target:package' /P:Configuration=Release /p:buildNumber=$BUILDNUMBER"
	
	Write-Host
    Write-Host "[$scriptName] $buildCommand"

	try {
        Invoke-Expression $buildCommand
		if(!$?){ taskWarning }
	} catch { exitException "Build_$PROJECT" }
    if ( $LASTEXITCODE -gt 0 ) { exitWithCode "Build_$PROJECT" $LASTEXITCODE }

    # remove the temp files so that they are not inadvertantly included in the artefact packacge
    itemRemove .\obj\Release\Package\PackageTmp
}

#>


<# Unit Test compile, linear deploy and execution example

itemRemove AssemblyInfo.cs
itemRemove bin
itemRemove obj
itemRemove $resultPrefix*
ItemRemove $userName*

if ( $ACTION -eq "clean" ) {

	Write-Host
	write-host "[$scriptName] Clean only." -ForegroundColor Blue

} else {

    write-host "[$scriptName] Build and linear deploy"

	# Build the Unit Test Project
    $msbuild = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\msbuild.exe"
    $buildCommand = "& $msbuild $PROJECT.csproj /P:Configuration=Release"
    Write-Host
    Write-Host "[$scriptName] $buildCommand"
	try {
        Invoke-Expression $buildCommand
		if(!$?){ taskWarning }
	} catch { exitException "Build_$PROJECT" }
    if ( $LASTEXITCODE -gt 0 ) { exitWithCode "Build_$PROJECT" $LASTEXITCODE }

    Write-Host
    Write-Host "[$scriptName] propertiesFile : $propertiesFile"
	$unitSource=$(..\autodeploy\remote\getProperty.ps1 $propertiesFile unitSource)
	write-host "unitSource     : $unitSource"

	$initialCatalog=$(..\autodeploy\remote\getProperty.ps1 $propertiesFile initialCatalog)
	write-host "initialCatalog : $initialCatalog"

	$sqlScripts=$(..\autodeploy\remote\getProperty.ps1 $propertiesFile sqlScripts)
	write-host "sqlScripts     : $sqlScripts"
	
	# Reuse the Database script runner to prepare the local database
    $buildCommand = '..\Database\bin\Release\Database.exe $initialCatalog $unitSource $sqlScripts'
    Write-Host
    Write-Host "[$scriptName] $buildCommand"
	try {
        Invoke-Expression $buildCommand
		if(!$?){ taskWarning }
	} catch { exitException "Detokenise_$PROJECT" }
    if ( $LASTEXITCODE -gt 0 ) { exitWithCode "Unit_Test_$PROJECT" $LASTEXITCODE }

	# Directly detokenise the app.config build artefact to configure unit test database connection
    $buildCommand = '..\autodeploy\remote\Transform.ps1 "$propertiesFile" "$unitTestConfig"'
    Write-Host
    Write-Host "[$scriptName] $buildCommand"
	try {
        Invoke-Expression $buildCommand
		if(!$?){ taskWarning }
	} catch { exitException "Detokenise_$PROJECT" }
    if ( $LASTEXITCODE -gt 0 ) { exitWithCode "Unit_Test_$PROJECT" $LASTEXITCODE }

	# Now perform the unit tests on the minimal linear deployed instance
    $msTest = "'C:\Program Files (x86)\Microsoft Visual Studio 11.0\Common7\IDE\MSTest.exe'"
    $buildCommand = "& $msTest /testcontainer:bin\Release\$PROJECT.dll /resultsfile:$resultPrefix$REVISION-Build_$BUILDNUMBER.trx"
    Write-Host
    Write-Host "[$scriptName] $buildCommand"
	try {
        Invoke-Expression $buildCommand
		if(!$?){ taskWarning }
	} catch { exitException "Unit_Test_$PROJECT" }
    if ( $LASTEXITCODE -gt 0 ) { exitWithCode "Unit_Test_$PROJECT" $LASTEXITCODE }

}
#>

<# Build Project using Visual Studio

if ( $ACTION -eq "clean" ) {

	Write-Host
	write-host "[$scriptName] Clean only." -ForegroundColor Blue

} else {

	# Release build using Visual Studio (installers are not natively supported by MSBuild)
    $buildCommand = "& '\\sxwprbb01\c$\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\devenv.com' ..\Phoenix.sln /Build 'Release' /Project SXPhoenixInstaller_PPG"

	Write-Host
    write-host "[$scriptName] Build using Visual Studio" -ForegroundColor Yellow

	Write-Host
    Write-Host "[$scriptName] $buildCommand"
	try {
        Invoke-Expression $buildCommand
		if(!$?){ taskWarning }
	} catch { exitException "Build_$PROJECT" }
    if ( $LASTEXITCODE -gt 0 ) { exitWithCode "Build_$PROJECT" $LASTEXITCODE }

}

#>

Write-Host "`n[$scriptName] ---------- stop ----------"
$error.clear()
exit 0