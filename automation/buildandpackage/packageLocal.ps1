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

$localArtifactListFile="$SOLUTIONROOT\storeForLocal"
$localPropertiesDir="$SOLUTIONROOT\propertiesForLocalTasks"
$localCustomDir="$SOLUTIONROOT\customLocal"
$localCryptDir="$SOLUTIONROOT\cryptLocal"
$remotePropertiesDir="$SOLUTIONROOT\propertiesForRemoteTasks"

Write-Host
Write-Host "[$scriptName] ---------------------------------------------------------------" 
Write-Host "[$scriptName]   WORK_DIR_DEFAULT             : $WORK_DIR_DEFAULT" 

Write-Host –NoNewLine "[$scriptName]   Local Artifact List          : " 
pathTest $localArtifactListFile

Write-Host –NoNewLine "[$scriptName]   Local Tasks Properties List  : " 
pathTest $localPropertiesDir

Write-Host –NoNewLine "[$scriptName]   Local Tasks Encrypted Data   : " 
pathTest $localCryptDir

Write-Host –NoNewLine "[$scriptName]   Local Tasks Custom Scripts   : " 
pathTest $localCustomDir

Write-Host –NoNewLine "[$scriptName]   Remote Tasks Properties List : " 
pathTest $remotePropertiesDir

# Create the workspace directory
Write-Host
Write-Host "[$scriptName] mkdir $WORK_DIR_DEFAULT" 
New-Item $WORK_DIR_DEFAULT -type directory > $null
if(!$?){ taskFailure ("mkdir $WORK_DIR_DEFAULT") }

# Copy Manifest
copySet "manifest.txt" "." $WORK_DIR_DEFAULT

# Copy all local script helpers, flat set to true to copy to root, not sub directory
copyDir ".\$AUTOMATIONROOT\local" $WORK_DIR_DEFAULT $true

# Copy all remote script helpers, flat set to true to copy to root, not sub directory
copyDir ".\$AUTOMATIONROOT\remote" $WORK_DIR_DEFAULT $true

# Copy the local tasks defintion file
if ( Test-Path "$SOLUTIONROOT\tasksRunLocal.tsk" ) {
	copySet "tasksRunLocal.tsk" "$SOLUTIONROOT" $WORK_DIR_DEFAULT
}

# Copy local properties if directory exists
if ( Test-Path $localPropertiesDir ) {
	copyDir $localPropertiesDir $WORK_DIR_DEFAULT
}

# Copy remote properties if directory exists
if ( Test-Path $remotePropertiesDir ) {
	copyDir $remotePropertiesDir $WORK_DIR_DEFAULT
}

# Copy encrypted file directory if it exists
if ( Test-Path $localCryptDir ) {
	copyDir $localCryptDir $WORK_DIR_DEFAULT
}

# Copy custom scripts directory if it exists
if ( Test-Path $localCustomDir ) {
	copyDir $localCustomDir $WORK_DIR_DEFAULT
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
