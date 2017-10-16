function taskFailure ($taskName) {
    write-host "[$scriptName] Failure excuting $taskName :" -ForegroundColor Red
    write-host "     Throwing exception : $scriptName HALT`n" -ForegroundColor Red
    throw "$scriptName HALT"
}

$SOLUTION = $args[0]
$BUILDNUMBER = $args[1]
$REVISION = $args[2]
$LOCAL_WORK_DIR = $args[3]
$WORK_DIR_DEFAULT = $args[4]
$SOLUTIONROOT = $args[5]
$AUTOMATIONROOT = $args[6]

$scriptName = $MyInvocation.MyCommand.Name
$remoteCustomDir = "$SOLUTIONROOT\customRemote"
$remoteCryptDir = "$SOLUTIONROOT\cryptRemote"
$remoteArtifactListFile = "$SOLUTIONROOT\storeForRemote"

Write-Host "`n[$scriptName] ---------------------------------------------------------------" 
Write-Host "[$scriptName]   WORK_DIR_DEFAULT             : $WORK_DIR_DEFAULT" 

Write-Host –NoNewLine "[$scriptName]   Remote Artifact List         : " 
pathTest $remoteArtifactListFile

Write-Host –NoNewLine "[$scriptName]   Remote Tasks Custom Scripts  : " 
pathTest $remoteCustomDir

Write-Host –NoNewLine "[$scriptName]   Remote Tasks Encrypted Data  : " 
pathTest $remoteCryptDir

# CDM-101 If Artefacts definition file is not found, do not perform any action, i.e. this solution is local tasks only
if ( -not (Test-Path $remoteArtifactListFile) ) {

	Write-Host "`n[$scriptName] Artefacts definition file not found $remoteArtifactListFile, therefore no action, assuming local tasks only."
	
} else {

	# Create the working directory and a subdiretory for the remote execution helper scripts
	Write-Host "`n[$scriptName] mkdir $WORK_DIR_DEFAULT" 
	New-Item $WORK_DIR_DEFAULT -type directory > $null
	if(!$?){ taskFailure "mkdir $WORK_DIR_DEFAULT"  }
	
	# Copy Manifest and CDAF Product Definition
	copySet "manifest.txt" "." $WORK_DIR_DEFAULT
	copySet "CDAF.windows" "$AUTOMATIONROOT" $WORK_DIR_DEFAULT
	Move-Item $WORK_DIR_DEFAULT\CDAF.windows $WORK_DIR_DEFAULT\CDAF.properties
	Write-Host "`n[$scriptName]   rename $WORK_DIR_DEFAULT\CDAF.windows --> $WORK_DIR_DEFAULT\CDAF.properties"
	
	# Copy helper scripts to deploy folder
	copyDir "$AUTOMATIONROOT\remote" $WORK_DIR_DEFAULT $true
	
	# Copy Remote Tasks driver file if it exists
	if ( Test-Path "$SOLUTIONROOT\tasksRunRemote.tsk" ) {
		copySet "tasksRunRemote.tsk" "$SOLUTIONROOT" $WORK_DIR_DEFAULT
	}
	
	# Copy encrypted file directory if it exists
	if ( Test-Path $remoteCryptDir ) {
		copyDir $remoteCryptDir $WORK_DIR_DEFAULT $true
	}
	
	# Copy custom scripts directory if it exists
	if ( Test-Path $remoteCustomDir ) {
		copyDir $remoteCustomDir $WORK_DIR_DEFAULT $true
	}
	
	# Copy remote artefacts if driver file exists exists
	# Copy artefacts if driver file exists exists
	if ( Test-Path $remoteArtifactListFile ) {
	
		# Pass the local work directory if the package is to be zipped
		& $AUTOMATIONROOT\buildandpackage\packageCopyArtefacts.ps1 $remoteArtifactListFile $WORK_DIR_DEFAULT 
	
	} else {
	
		Write-Host "`n[$scriptName] Remote Artifact file ($remoteArtifactListFile) does not exist, packaging framework scripts only" -ForegroundColor Yellow
	
	}
	
	# Zip the working directory to create the artefact Package
	ZipFiles "$(pwd)\${SOLUTION}-${BUILDNUMBER}.zip" "$(pwd)\$WORK_DIR_DEFAULT"
}
