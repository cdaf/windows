# When using a custom build script, arguments must be managed 
$SOLUTION = $args[0]
$BUILDNUMBER = $args[1]
$REVISION = $args[2]
$PROJECT = $args[3]
$ENVIRONMENT = $args[4]
$ACTION = $args[5]

$exitStatus = 0

$scriptName = $MyInvocation.MyCommand.Name
$userName = [Environment]::UserName

<#
Write-Host
Write-Host "[$scriptName] SOLUTION    = $SOLUTION"
Write-Host "[$scriptName] BUILDNUMBER = $BUILDNUMBER"
Write-Host "[$scriptName] REVISION    = $REVISION"
Write-Host "[$scriptName] PROJECT     = $PROJECT"
Write-Host "[$scriptName] ENVIRONMENT = $ENVIRONMENT"
Write-Host "[$scriptName] ACTION      = $ACTION"
#>

<# Properties file loader, all properties are instantiated as runtime variables and listed in the logs
write-host "The transform does not support relative paths, so the parent path must be resolved before invokation"
$parentPath = (Get-Item -Path "..\" -Verbose).FullName
..\autodeploy\remote\Transform.ps1 "$parentPath\autodeploy\solution\propertiesForLocalTasks\$ENVIRONMENT" | ForEach-Object { invoke-expression $_ }
#>

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