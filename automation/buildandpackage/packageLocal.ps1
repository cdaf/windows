Param (
	[string]$SOLUTION,
	[string]$BUILDNUMBER,
	[string]$REVISION,
	[string]$WORK_DIR_DEFAULT,
	[string]$SOLUTIONROOT,
	[string]$AUTOMATIONROOT
)

function taskFailure ($taskName) {
    write-host
    write-host "[$scriptName] Failure excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    write-host "     Throwing exception : $scriptName HALT" -ForegroundColor Red
	write-host
    throw "$scriptName HALT"
}

# 1.7.8 Merge files into directory, i.e. don't replace any properties provided above
function propMerge ($generatedPropDir, $generatedPropertyFile) {
	Write-Host "`n[$scriptName] Processing generated properties directory (${generatedPropDir}):`n"
	if ( ! ( Test-Path "$WORK_DIR_DEFAULT\${generatedPropDir}" )) {
		Write-Host "[$scriptName]   $(mkdir $WORK_DIR_DEFAULT\${generatedPropDir})"
	}
	foreach ( $generatedPropertyFile in (Get-ChildItem ".\${generatedPropDir}")) {
		Write-Host "[$scriptName]   ${generatedPropDir}\${generatedPropertyFile} --> $WORK_DIR_DEFAULT\${generatedPropDir}\${generatedPropertyFile}"
		Get-Content ".\${generatedPropDir}\${generatedPropertyFile}" | Add-Content "$WORK_DIR_DEFAULT\${generatedPropDir}\${generatedPropertyFile}"
	}
}

$scriptName = $MyInvocation.MyCommand.Name

$localArtifactListFile    = "$SOLUTIONROOT\storeForLocal"
$genericArtifactList      = "$SOLUTIONROOT\storeFor"
$localPropertiesDir       = "$SOLUTIONROOT\propertiesForLocalTasks"
$localGenPropDir          = "propertiesForLocalTasks"
$localEnvironmentPath     = "$SOLUTIONROOT\propertiesForLocalEnvironment"
$localCustomDir           = "$SOLUTIONROOT\customLocal"
$commonCustomDir          = "$SOLUTIONROOT\custom"
$localCryptDir            = "$SOLUTIONROOT\cryptLocal"
$cryptDir                 = "$SOLUTIONROOT\crypt"
$remotePropertiesDir      = "$SOLUTIONROOT\propertiesForRemoteTasks"
$remoteGenPropDir         = "propertiesForRemoteTasks"
$containerPropertiesDir   = "$SOLUTIONROOT\propertiesForContainerTasks"
$containerGenPropDir      = "propertiesForContainerTasks"

Write-Host
Write-Host "[$scriptName] ---------------------------------------------------------------" 
Write-Host "[$scriptName]   WORK_DIR_DEFAULT                : $WORK_DIR_DEFAULT" 

Write-Host -NoNewLine "[$scriptName]   Local Artifact List             : " 
pathTest $localArtifactListFile

Write-Host -NoNewLine "[$scriptName]   Generic Artifact List           : " 
pathTest $genericArtifactList

Write-Host -NoNewLine "[$scriptName]   Local Tasks Properties List     : " 
pathTest $localPropertiesDir

Write-Host -NoNewLine "[$scriptName]   Generated local properties      : " 
pathTest $localGenPropDir

Write-Host -NoNewLine "[$scriptName]   Local Environment Properties    : " 
pathTest $localEnvironmentPath

Write-Host -NoNewLine "[$scriptName]   Local Tasks Encrypted Data      : " 
pathTest $localCryptDir

Write-Host -NoNewLine "[$scriptName]   Common Encrypted Data           : " 
pathTest $cryptDir

Write-Host -NoNewLine "[$scriptName]   Local Tasks Custom Scripts      : " 
pathTest $localCustomDir

Write-Host -NoNewLine "[$scriptName]   Common Custom Scripts           : " 
pathTest $commonCustomDir

Write-Host -NoNewLine "[$scriptName]   Remote Tasks Properties List    : " 
pathTest $remotePropertiesDir

Write-Host -NoNewLine "[$scriptName]   Generated remote properties     : " 
pathTest $remoteGenPropDir

Write-Host -NoNewLine "[$scriptName]   Container Tasks Properties List : " 
pathTest $containerPropertiesDir

Write-Host -NoNewLine "[$scriptName]   Generated Container properties  : " 
pathTest $containerGenPropDir

# Create the workspace directory
if ( Test-Path "$WORK_DIR_DEFAULT" ) {
	Write-Host "`n[$scriptName] $WORK_DIR_DEFAULT already exists, assume created by package.tsk, no action required" 
} else {
	Write-Host "`n[$scriptName] mkdir $WORK_DIR_DEFAULT and seed with solution files" 
	New-Item $WORK_DIR_DEFAULT -type directory > $null
	if(!$?){ taskFailure ("mkdir $WORK_DIR_DEFAULT") }
}

# Copy Manifest and CDAF Product Definition
copySet "manifest.txt" "." $WORK_DIR_DEFAULT
copySet "CDAF.windows" "$AUTOMATIONROOT" $WORK_DIR_DEFAULT\CDAF.properties

# Copy the override or default delivery process
if (Test-Path "$solutionRoot\delivery.bat") {
	copySet "delivery.bat" "$solutionRoot" $WORK_DIR_DEFAULT
	copySet "delivery.ps1" "$solutionRoot" $WORK_DIR_DEFAULT
} else {
	copySet "delivery.bat" "$AUTOMATIONROOT\processor" $WORK_DIR_DEFAULT
	copySet "delivery.ps1" "$AUTOMATIONROOT\processor" $WORK_DIR_DEFAULT
}

# Copy all local script helpers, flat set to true to copy to root, not sub directory
copyDir "$AUTOMATIONROOT\local" $WORK_DIR_DEFAULT $true

# Copy all remote script helpers, flat set to true to copy to root, not sub directory
copyDir "$AUTOMATIONROOT\remote" $WORK_DIR_DEFAULT $true

Write-Host "`n[$scriptName] Copy local and remote defintions`n"
$listOfTaskFile = "tasksRunLocal.tsk", "tasksRunRemote.tsk"
foreach ($file in $listOfTaskFile) {
	if ( test-Path "$SOLUTIONROOT\$file" ) {
		copySet "$file" "$SOLUTIONROOT" "$WORK_DIR_DEFAULT"
	}
}

# 1.7.8 Merge generic tasks into explicit tasks
if ( Test-Path "$SOLUTIONROOT\tasksRun.tsk" ) {
	foreach ($file in $listOfTaskFile) {
		Write-Host "[$scriptName]   $SOLUTIONROOT\tasksRun.tsk --> $WORK_DIR_DEFAULT\$file"
		Get-Content "$SOLUTIONROOT\tasksRun.tsk" | Add-Content "$WORK_DIR_DEFAULT\$file"
	}
}

# Copy local properties to propertiesForLocalTasks (iteration driver)
if ( Test-Path $localPropertiesDir ) {
	copyDir $localPropertiesDir $WORK_DIR_DEFAULT
}

if ( Test-Path ".\$localGenPropDir" ) {
	propMerge $localGenPropDir $generatedPropertyFile
}

# Copy local environment properties (pre and post target process)
if ( Test-Path $localEnvironmentPath ) {
	copyDir $localEnvironmentPath $WORK_DIR_DEFAULT
}

# Copy remote properties if directory exists
if ( Test-Path $remotePropertiesDir ) {
	copyDir $remotePropertiesDir $WORK_DIR_DEFAULT
}

if ( Test-Path ".\$remoteGenPropDir" ) {
	propMerge $remoteGenPropDir $generatedPropertyFile
}

# Merge files into directory, i.e. don't replace any properties provided above
if ( Test-Path $containerPropertiesDir ) {
	copyDir $containerPropertiesDir $WORK_DIR_DEFAULT
}

# 2.4.0 extend for container properties, processed locally, but using remote artefacts for execution
if ( Test-Path ".\$containerGenPropDir" ) {
	propMerge $containerGenPropDir $generatedPropertyFile
}

# Copy encrypted file directory if it exists
if ( Test-Path $localCryptDir ) {
	copyDir $localCryptDir $WORK_DIR_DEFAULT
}

if ( Test-Path $cryptDir ) {
	copyDir $cryptDir $WORK_DIR_DEFAULT
}

# Copy custom scripts if custom directory exists, copy to root of workspace 
if ( Test-Path $localCustomDir ) {
	copyDir $localCustomDir $WORK_DIR_DEFAULT $true
}

# 1.6.7 Copy common custom scripts if custom directory exists, copy to root of workspace 
if ( Test-Path $commonCustomDir ) {
	copyDir $commonCustomDir $WORK_DIR_DEFAULT $true
}

# Copy artefacts if driver file exists
if ( Test-Path $localArtifactListFile ) {
	try {
		& $AUTOMATIONROOT\buildandpackage\packageCopyArtefacts.ps1 $localArtifactListFile $WORK_DIR_DEFAULT 
		if(!$?){ taskFailure "& $AUTOMATIONROOT\buildandpackage\packageCopyArtefacts.ps1 $localArtifactListFile $WORK_DIR_DEFAULT" }
	} catch { taskFailure "& $AUTOMATIONROOT\buildandpackage\packageCopyArtefacts.ps1 $localArtifactListFile $WORK_DIR_DEFAULT" }
}

# 1.7.8 Copy generic artefacts if driver file exists
if ( Test-Path $genericArtifactList ) {
	try {
		& $AUTOMATIONROOT\buildandpackage\packageCopyArtefacts.ps1 $genericArtifactList $WORK_DIR_DEFAULT 
		if(!$?){ taskFailure "& $AUTOMATIONROOT\buildandpackage\packageCopyArtefacts.ps1 $genericArtifactList $WORK_DIR_DEFAULT" }
	} catch { taskFailure "& $AUTOMATIONROOT\buildandpackage\packageCopyArtefacts.ps1 $genericArtifactList $WORK_DIR_DEFAULT" }
}

# Zip the working directory to create the artefact Package, CDAF.solution and build time values
# (SOLUTION and BUILDNUMBER) are merged into the manifest file.
$propertiesFile = "$WORK_DIR_DEFAULT\manifest.txt"
try {
	$zipLocal=$(& $WORK_DIR_DEFAULT\getProperty.ps1 "$propertiesFile" 'zipLocal')
	if(!$?){
		throw "`$zipLocal=`$(& $WORK_DIR_DEFAULT\getProperty.ps1 $propertiesFile zipLocal)"
		throw "Exception Reading zipLocal property from $AUTOMATIONROOT\manifest.txt" 
	}
} catch { 
	Write-Host "Exception attempting `$zipLocal=`$(& $WORK_DIR_DEFAULT\getProperty.ps1 $propertiesFile zipLocal)"
	throw "Exception Reading zipLocal property from $AUTOMATIONROOT\manifest.txt" 
}

if ( "$zipLocal" -eq 'yes' ) {

	ZipFiles "$(Get-Location)\${SOLUTION}-local-${BUILDNUMBER}.zip" "$(Get-Location)\$WORK_DIR_DEFAULT"

} else {
	Write-Host "`n[$scriptName] zipLocal property not found in manifest.txt (CDAF.solution), no further action required."
}
