function taskFailure ($taskName) {
    write-host "[$scriptName] Failure excuting $taskName :" -ForegroundColor Red
    write-host "     Throwing exception : $scriptName HALT" -ForegroundColor Red
	write-host
    throw "$scriptName HALT"
}

$SOLUTION = $args[0]
$BUILDNUMBER = $args[1]
$REVISION = $args[2]
$LOCAL_WORK_DIR = $args[3]
$WORK_DIR_DEFAULT = $args[4]
$SCRIPT_DIR = $args[5]
$SOLUTIONROOT = $args[6]
$AUTOMATIONROOT = $args[7]

$scriptName = $MyInvocation.MyCommand.Name
$remoteCustomDir = "$SOLUTIONROOT\customRemote"
$remoteCryptDir = "$SOLUTIONROOT\cryptRemote"
$remoteArtifactListFile = "$SOLUTIONROOT\storeForRemote"

Write-Host
Write-Host "[$scriptName] ---------------------------------------------------------------" 
Write-Host "[$scriptName]   WORK_DIR_DEFAULT             : $WORK_DIR_DEFAULT" 

Write-Host –NoNewLine "[$scriptName]   Remote Artifact List         : " 
pathTest $remoteArtifactListFile

Write-Host –NoNewLine "[$scriptName]   Remote Tasks Custom Scripts  : " 
pathTest $remoteCustomDir

Write-Host –NoNewLine "[$scriptName]   Remote Tasks Encrypted Data  : " 
pathTest $remoteCryptDir

# Create the working directory and a subdiretory for the remote execution helper scripts
Write-Host
Write-Host "[$scriptName] mkdir $WORK_DIR_DEFAULT" 
New-Item $WORK_DIR_DEFAULT -type directory > $null
if(!$?){ taskFailure "mkdir $WORK_DIR_DEFAULT" }
Write-Host
Write-Host "[$scriptName] mkdir $WORK_DIR_DEFAULT\$SCRIPT_DIR" 
New-Item $WORK_DIR_DEFAULT\$SCRIPT_DIR -type directory > $null
if(!$?){ taskFailure "mkdir $WORK_DIR_DEFAULT\$SCRIPT_DIR"  }

# Copy Manifest
copySet "manifest.txt" "." $WORK_DIR_DEFAULT

# Copy helper scripts to deploy folder
copyDir "$AUTOMATIONROOT\remote" $WORK_DIR_DEFAULT\$SCRIPT_DIR $true

# Copy Remote Tasks driver file if it exists
if ( Test-Path "$SOLUTIONROOT\tasksRunRemote.tsk" ) {
	copySet "tasksRunRemote.tsk" "$SOLUTIONROOT" $WORK_DIR_DEFAULT\$SCRIPT_DIR
}

# Copy encrypted file directory if it exists
if ( Test-Path $remoteCryptDir ) {
	copyDir $remoteCryptDir $WORK_DIR_DEFAULT
}

# Copy custom scripts directory if it exists
if ( Test-Path $remoteCustomDir ) {
	copyDir $remoteCustomDir $WORK_DIR_DEFAULT
}

# Copy remote artefacts if driver file exists exists
# Copy artefacts if driver file exists exists
if ( Test-Path $remoteArtifactListFile ) {

	# Pass the local work directory if the package is to be zipped
	& $AUTOMATIONROOT\buildandpackage\packageCopyArtefacts.ps1 $remoteArtifactListFile $WORK_DIR_DEFAULT 

} else {

	Write-Host
	Write-Host "[$scriptName] Remote Artifact file ($remoteArtifactListFile) does not exist, packaging framework scripts only" -ForegroundColor Yellow

}

# Zip the working directory to create the artefact Package
cd $WORK_DIR_DEFAULT

$packageCommand = "& ..\$LOCAL_WORK_DIR\7za.exe a ..\$SOLUTION-$BUILDNUMBER.zip ."

Write-Host
Write-Host "[$scriptName] $packageCommand"
Invoke-Expression $packageCommand
$exitcode = $LASTEXITCODE
if ( $exitcode -gt 0 ) { 
	Write-Host
	Write-Host "[$scriptName] Package creation (Zip) failed with exit code = $exitcode" -ForegroundColor Red
	throw "Package creation (Zip) failed with exit code = $exitcode" 
}

cd..
