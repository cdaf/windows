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

$scriptName             = $MyInvocation.MyCommand.Name
$remoteCustomDir        = "$SOLUTIONROOT\customRemote"
$commonCustomDir        = "$SOLUTIONROOT\custom"
$remoteCryptDir         = "$SOLUTIONROOT\cryptRemote"
$remoteArtifactListFile = "$SOLUTIONROOT\storeForRemote"
$genericArtifactList    = "$SOLUTIONROOT\storeFor"

Write-Host "`n[$scriptName] ---------------------------------------------------------------" 
Write-Host "[$scriptName]   WORK_DIR_DEFAULT             : $WORK_DIR_DEFAULT" 

Write-Host –NoNewLine "[$scriptName]   Remote Artifact List         : " 
pathTest $remoteArtifactListFile

Write-Host –NoNewLine "[$scriptName]   Generic Artifact List        : " 
pathTest $genericArtifactList

Write-Host –NoNewLine "[$scriptName]   Remote Tasks Custom Scripts  : " 
pathTest $remoteCustomDir

Write-Host –NoNewLine "[$scriptName]   Common Custom Scripts        : " 
pathTest $commonCustomDir

Write-Host –NoNewLine "[$scriptName]   Remote Tasks Encrypted Data  : " 
pathTest $remoteCryptDir


# CDM-101 If Artefacts definition file is not found, do not perform any action, i.e. this solution is local tasks only
if ( (-not (Test-Path $remoteArtifactListFile)) -and  (-not (Test-Path $genericArtifactList))) {

	Write-Host "`n[$scriptName] Artefacts definition file not found $remoteArtifactListFile, therefore no action, assuming local tasks only."
	
} else {

	# Create the working directory and a subdiretory for the remote execution helper scripts
	Write-Host "`n[$scriptName] mkdir $WORK_DIR_DEFAULT" 
	New-Item $WORK_DIR_DEFAULT -type directory > $null
	if(!$?){ taskFailure "mkdir $WORK_DIR_DEFAULT"  }
	
	# Copy Manifest and CDAF Product Definition
	copySet "manifest.txt" "." $WORK_DIR_DEFAULT
	copySet "CDAF.windows" "$AUTOMATIONROOT" $WORK_DIR_DEFAULT\CDAF.properties
	
	# Copy helper scripts to deploy folder
	copyDir "$AUTOMATIONROOT\remote" $WORK_DIR_DEFAULT $true
	
	# Copy Remote Tasks driver file if it exists
	if ( Test-Path "$SOLUTIONROOT\tasksRunRemote.tsk" ) {
		copySet "tasksRunRemote.tsk" "$SOLUTIONROOT" $WORK_DIR_DEFAULT
	}

	# 1.7.8 Merge generic tasks into explicit tasks
	if ( Test-Path "$SOLUTIONROOT\tasksRun.tsk" ) {
		Write-Host "[$scriptName]   $SOLUTIONROOT/tasksRun.tsk --> $WORK_DIR_DEFAULT\tasksRunRemote.tsk"
		Get-Content ".\$SOLUTIONROOT\tasksRun.tsk" | Add-Content "$WORK_DIR_DEFAULT\tasksRunRemote.tsk"
	}
	
	# Copy encrypted file directory if it exists
	if ( Test-Path $remoteCryptDir ) {
		copyDir $remoteCryptDir $WORK_DIR_DEFAULT $true
	}
	
	# Copy custom scripts directory if it exists
	if ( Test-Path $remoteCustomDir ) {
		copyDir $remoteCustomDir $WORK_DIR_DEFAULT $true
	}

	# 1.6.7 Copy common custom scripts if custom directory exists, copy to root of workspace 
	if ( Test-Path $commonCustomDir ) {
		copyDir $commonCustomDir $WORK_DIR_DEFAULT $true
	}
	
	# Copy remote artefacts if driver file exists
	if ( Test-Path $remoteArtifactListFile ) {
	
		# Pass the local work directory if the package is to be zipped
		& $AUTOMATIONROOT\buildandpackage\packageCopyArtefacts.ps1 $remoteArtifactListFile $WORK_DIR_DEFAULT 
	}

	# 1.7.8 Copy generic artefacts if driver file exists
	if ( Test-Path $genericArtifactList ) {
	
		# Pass the local work directory if the package is to be zipped
		& $AUTOMATIONROOT\buildandpackage\packageCopyArtefacts.ps1 $genericArtifactList $WORK_DIR_DEFAULT 
	}
	
	# Zip the working directory to create the artefact Package
	ZipFiles "$(pwd)\${SOLUTION}-${BUILDNUMBER}.zip" "$(pwd)\$WORK_DIR_DEFAULT"
}
