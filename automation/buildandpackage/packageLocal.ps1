function taskFailure ($taskName) {
    write-host
    write-host "[$scriptName] Failure excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    write-host "     Throwing exception : $scriptName HALT" -ForegroundColor Red
	write-host
    throw "$scriptName HALT"
}

$SOLUTION = $args[0]
$BUILDNUMBER = $args[1]
$REVISION = $args[2]
$WORK_DIR_DEFAULT = $args[3]
$SOLUTIONROOT = $args[4]
$AUTOMATIONROOT = $args[5]

$scriptName = $MyInvocation.MyCommand.Name

$localArtifactListFile = "$SOLUTIONROOT\storeForLocal"
$localPropertiesDir    = "$SOLUTIONROOT\propertiesForLocalTasks"
$localEnvironmentPath  = "$SOLUTIONROOT\propertiesForLocalEnvironment"
$localCustomDir        = "$SOLUTIONROOT\customLocal"
$localCryptDir         = "$SOLUTIONROOT\cryptLocal"
$remotePropertiesDir   = "$SOLUTIONROOT\propertiesForRemoteTasks"

Write-Host
Write-Host "[$scriptName] ---------------------------------------------------------------" 
Write-Host "[$scriptName]   WORK_DIR_DEFAULT             : $WORK_DIR_DEFAULT" 

Write-Host –NoNewLine "[$scriptName]   Local Artifact List          : " 
pathTest $localArtifactListFile

Write-Host –NoNewLine "[$scriptName]   Local Tasks Properties List  : " 
pathTest $localPropertiesDir

Write-Host –NoNewLine "[$scriptName]   Local Environment Properties : " 
pathTest $localEnvironmentPath

Write-Host –NoNewLine "[$scriptName]   Local Tasks Encrypted Data   : " 
pathTest $localCryptDir

Write-Host –NoNewLine "[$scriptName]   Local Tasks Custom Scripts   : " 
pathTest $localCustomDir

Write-Host –NoNewLine "[$scriptName]   Remote Tasks Properties List : " 
pathTest $remotePropertiesDir

# Create the workspace directory
Write-Host
Write-Host "[$scriptName] mkdir $WORK_DIR_DEFAULT and seed with solution files" 
New-Item $WORK_DIR_DEFAULT -type directory > $null
if(!$?){ taskFailure ("mkdir $WORK_DIR_DEFAULT") }

# Copy Manifest and CDAF Product Definition
copySet "manifest.txt" "." $WORK_DIR_DEFAULT
copySet "CDAF.windows" "$AUTOMATIONROOT" $WORK_DIR_DEFAULT
Move-Item $WORK_DIR_DEFAULT\CDAF.windows $WORK_DIR_DEFAULT\CDAF.properties
Write-Host Write-Host "[$scriptName]   rename $WORK_DIR_DEFAULT\CDAF.windows --> $WORK_DIR_DEFAULT\CDAF.properties"

# Copy all local script helpers, flat set to true to copy to root, not sub directory
copyDir ".\$AUTOMATIONROOT\local" $WORK_DIR_DEFAULT $true

# Copy all remote script helpers, flat set to true to copy to root, not sub directory
copyDir ".\$AUTOMATIONROOT\remote" $WORK_DIR_DEFAULT $true

Write-Host Write-Host "[$scriptName]  Copy all tasks definition files"
$files = Get-ChildItem $workingDirectory -Filter "$SOLUTIONROOT\*.tsk"
foreach ($file in $files) {
	copySet "$file" "$SOLUTIONROOT" "$WORK_DIR_DEFAULT"
}

# Copy local properties to propertiesForLocalTasks (iteration driver)
if ( Test-Path $localPropertiesDir ) {
	copyDir $localPropertiesDir $WORK_DIR_DEFAULT
}

# Copy local environment properties (pre and post target process)
if ( Test-Path $localEnvironmentPath ) {
	copyDir $localEnvironmentPath $WORK_DIR_DEFAULT
}

# Copy remote properties if directory exists
if ( Test-Path $remotePropertiesDir ) {
	copyDir $remotePropertiesDir $WORK_DIR_DEFAULT
}

# Copy encrypted file directory if it exists
if ( Test-Path $localCryptDir ) {
	copyDir $localCryptDir $WORK_DIR_DEFAULT
}

# CDM-114 Copy custom scripts if custom directory exists, copy to root of workspace 
if ( Test-Path $localCustomDir ) {
	copyDir $localCustomDir $WORK_DIR_DEFAULT $true
}

# Copy artefacts if driver file exists exists
if ( Test-Path $localArtifactListFile ) {

	try {
		& .\$AUTOMATIONROOT\buildandpackage\packageCopyArtefacts.ps1 $localArtifactListFile $WORK_DIR_DEFAULT 
		if(!$?){ taskFailure "& .\$AUTOMATIONROOT\buildandpackage\packageCopyArtefacts.ps1 $localArtifactListFile $WORK_DIR_DEFAULT" }
	} catch { taskFailure "& .\$AUTOMATIONROOT\buildandpackage\packageCopyArtefacts.ps1 $localArtifactListFile $WORK_DIR_DEFAULT" }

} else {

	Write-Host
	Write-Host "[$scriptName] Local Artifact file ($localArtifactListFile) does not exist, packaging framework scripts only" -ForegroundColor Yellow

}
