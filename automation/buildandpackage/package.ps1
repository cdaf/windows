function itemRemove ($itemPath, $ignoreLock) { 
# If item exists, and is a directory, recursively remove hidden and read-only attributes or to explicit file name if just a file 
	if ( Test-Path $itemPath ) {
		if ( (Get-Item $itemPath) -is [System.IO.DirectoryInfo] ) {
			attrib -r -h *.* /s /d
		} else {
			attrib -r -h $itemPath /s
		}	
		write-host "[$scriptName] Delete $itemPath"
		try {
			Remove-Item $itemPath -Recurse
			if(!$?) {
				if ( $ignoreLock ) {
					write-host "[$scriptName] Warning : $error[0], but `$ignoreLock set to $ignoreLock, continuing..."
					cmd /c "exit 0"
				} else {
					taskFailure ("Remove-Item $itemPath -Recurse")
				}
			}
		} catch {
			ERRMSG "Remove-Item $itemPath -Recurse" 9157
		}
	}
}

function getFilename ($FullPathName) {

	$PIECES=$FullPathName.split('\') 
	$NUMBEROFPIECES=$PIECES.Count 
	$FILENAME=$PIECES[$NumberOfPieces-1] 
	$DIRECTORYPATH=$FullPathName.Trim($FILENAME) 
	return $FILENAME

}

function pathTest ($pathToTest) { 
	if ( Test-Path $pathToTest ) {
		Write-Host "found ($pathToTest)"
	} else {
		Write-Host "none ($pathToTest)"
	}
}

function copyDir ($sourceDir, $targetDir, $flat) {
	Write-Host
	if (-not ($flat)) {
		$dirName = getFilename($sourceDir)
		Write-Host "[$scriptName] mkdir $targetDir\$dirName" 
		New-Item $targetDir\$dirName -type directory > $null
	}
	if(!$?){ taskFailure ("mkdir $targetDir\$dirName") }
	foreach ($item in (Get-ChildItem -Path $sourceDir)) {
		if ($flat) {
			copySet $item.Name $sourceDir $targetDir
		} else {
			copySet $item.Name $sourceDir $targetDir\$dirName
		}
	}
}

function copySet ($item, $from, $to) {

	Write-Host "[$scriptName]   $from\$item --> $to" 
	Copy-Item $from\$item $to -Force
	if(!$?){ $error ; taskFailure "[$scriptName (copySet)] copy $from\$item to $to failed" }
	if ( Test-Path $to -pathType container ) {
		Set-ItemProperty $to\$item -name IsReadOnly -value $false
		if(!$?){ $error ; taskFailure "[$scriptName (copySet)] remove read only from $to\$item" }
	} else {
		Set-ItemProperty $to -name IsReadOnly -value $false
		if(!$?){ $error ; taskFailure "[$scriptName (copySet)] remove read only from $to" }
	}
}

function ZipFiles( $zipfilename, $sourcedir )
{
	try {
		Add-Type -Assembly System.IO.Compression.FileSystem
	} catch {
		taskFailure "Failed to load Compression assembly, is .NET 4.5 or above installed?"
	}
	$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
	Write-Host "[package.ps1] Create zip package $zipfilename from $sourcedir"
	[System.IO.Compression.ZipFile]::CreateFromDirectory($sourcedir, $zipfilename, $compressionLevel, $false)
	foreach ($item in (Get-ChildItem -Path $sourcedir)) {
		Write-Host "[package.ps1]   --> $item"
	}
	
}

$scriptName = 'package.ps1'
Write-Host "`n[$scriptName] +-----------------+"
Write-Host "[$scriptName] | Package Process |"
Write-Host "[$scriptName] +-----------------+"

$SOLUTION = $args[0]
if (-not($SOLUTION)) { ERRMSG "SOLUTION_NOT_PASSED" 9150 }
Write-Host "[$scriptName]   SOLUTION                   : $SOLUTION"

$BUILDNUMBER = $args[1]
if (-not($BUILDNUMBER)) { ERRMSG "BUILDNUMBER_NOT_PASSED" 9151 }
Write-Host "[$scriptName]   BUILDNUMBER                : $BUILDNUMBER"

$REVISION = $args[2]
if (-not($REVISION)) { ERRMSG "REVISION_NOT_PASSED" 9152 }
Write-Host "[$scriptName]   REVISION                   : $REVISION"

$AUTOMATIONROOT=$args[3]
if (-not($LOCAL_WORK_DIR)) { ERRMSG "AUTOMATIONROOT_NOT_PASSED" 9153 }
Write-Host "[$scriptName]   AUTOMATIONROOT             : $AUTOMATIONROOT"

$SOLUTIONROOT=$args[4]
if (-not($LOCAL_WORK_DIR)) { ERRMSG "SOLUTIONROOT_NOT_PASSED" 9154 }
Write-Host "[$scriptName]   SOLUTIONROOT               : $SOLUTIONROOT"

$LOCAL_WORK_DIR = $args[5]
if (-not($LOCAL_WORK_DIR)) { ERRMSG "LOCAL_NOT_PASSED" 9155 }
Write-Host "[$scriptName]   LOCAL_WORK_DIR             : $LOCAL_WORK_DIR"

$REMOTE_WORK_DIR = $args[6]
if (-not($REMOTE_WORK_DIR)) { ERRMSG "REMOTE_NOT_PASSED" 9156 }
Write-Host "[$scriptName]   REMOTE_WORK_DIR            : $REMOTE_WORK_DIR"

$ACTION = $args[7]
Write-Host "[$scriptName]   ACTION                     : $ACTION"

$prepackageTask = "$SOLUTIONROOT\package.tsk"
Write-Host -NoNewLine "[$scriptName]   Prepackage Tasks           : " 
if (Test-Path "$prepackageTask") {
	Write-Host "found ($prepackageTask)"
} else {
	Write-Host "none ($prepackageTask)"
}

$prepackageScript = ".\package.ps1"
Write-Host -NoNewLine "[$scriptName]   Prepackage Script          : " 
if (Test-Path "$prepackageScript") {
	Write-Host "found ($prepackageScript)"
} else {
	Write-Host "none ($prepackageScript)"
}

$postpackageTasks = "$SOLUTIONROOT\wrap.tsk"
Write-Host -NoNewLine "[$scriptName]   Postpackage Tasks          : " 
if (Test-Path "$postpackageTasks") {
	Write-Host "found ($postpackageTasks)"
} else {
	Write-Host "none ($postpackageTasks)"
}

# Test for optional properties
$remotePropertiesDir = "$SOLUTIONROOT\propertiesForRemoteTasks"
Write-Host -NoNewLine "[$scriptName]   Remote Target Directory    : " 

if ( Test-Path $remotePropertiesDir ) {
	Write-Host "found ($remotePropertiesDir)"
} else {
	Write-Host "none ($remotePropertiesDir)"
}
$containerPropertiesDir = "$SOLUTIONROOT\propertiesForContainerTasks"
Write-Host -NoNewLine "[$scriptName]   Container Target Directory : " 

if ( Test-Path $containerPropertiesDir ) {
	Write-Host "found ($containerPropertiesDir)"
} else {
	Write-Host "none ($containerPropertiesDir)"
}

# Runtime information, build process can have large logging, so this is repeated
Write-Host "[$scriptName]   pwd                        : $(Get-Location)"
Write-Host "[$scriptName]   hostname                   : $(hostname)" 
Write-Host "[$scriptName]   whoami                     : $(whoami)" 

$propertiesFile = "$AUTOMATIONROOT\CDAF.windows"
$propName = "productVersion"
try {
	$cdafVersion=$(& $AUTOMATIONROOT\remote\getProperty.ps1 $propertiesFile $propName)
	if(!$?){ ERRMSG "Property retrieval of $propName from $propertiesFile halted." }
} catch { ERRMSG "PACK_GET_CDAF_VERSION" 9158 }
Write-Host "[$scriptName]   CDAF Version               : $cdafVersion"

$propertiesFile = "$SOLUTIONROOT\CDAF.solution"
$propName = "packageFeatures"
try {
	$packageFeatures=$(& $AUTOMATIONROOT\remote\getProperty.ps1 $propertiesFile $propName)
	if(!$?){ ERRMSG "Property retrieval of $propName from $propertiesFile halted." }
} catch { ERRMSG "PACK_FEATUES_CDAF_VERSION" 9158 }
if ( $packageFeatures) {
	Write-Host "[$scriptName]   packageFeatures            : $packageFeatures (option minimal)"
} else {
	Write-Host "[$scriptName]   packageFeatures            : (optional property not set, option minimal)"
}

# Cannot brute force clear the workspace as the Visual Studio solution file is here
write-host "`n[$scriptName]   --- Start Package Process ---`n" -ForegroundColor Green
itemRemove ".\storeForRemote_manifest.txt"
itemRemove ".\storeForLocal_manifest.txt"
itemRemove ".\$SOLUTION*.zip"
itemRemove ".\*.nupkg"
itemRemove "$LOCAL_WORK_DIR"
itemRemove "$REMOTE_WORK_DIR"
itemRemove "artifacts"
itemRemove "${SOLUTION}.ps1"

# Process solution properties if defined
if (Test-Path "$SOLUTIONROOT\CDAF.solution") {
	write-host "`n[$scriptName] Load solution properties from $SOLUTIONROOT\CDAF.solution"
	& $AUTOMATIONROOT\remote\Transform.ps1 "$SOLUTIONROOT\CDAF.solution" | ForEach-Object { invoke-expression $_ }
}

# Process optional pre-packaging tasks (Task driver support added in release 0.7.2)
if (Test-Path "$prepackageTask") {
	Write-Host "`n[$scriptName] Process Pre-Package Task ...`n"
	executeExpression "& '$AUTOMATIONROOT\remote\execute.ps1' '$SOLUTION' '$BUILDNUMBER' 'package' '$prepackageTask' '$ACTION'"
}

# Process optional pre-packaging script (Script driver support added in release 1.8.14)
if (Test-Path $prepackageScript) {
	Write-Host "`n[$scriptName] Process Pre-Package Script ...`n"
	executeExpression "& '$prepackageScript' '$SOLUTION' '$BUILDNUMBER' '$ACTION'"
}

# Load Manifest, these properties are used by remote deployment
Add-Content manifest.txt "# Manifest for revision $SOLUTION"
Add-Content manifest.txt "SOLUTION=$SOLUTION"
Add-Content manifest.txt "BUILDNUMBER=$BUILDNUMBER"
Add-Content manifest.txt "REVISION=$REVISION"
# CDM-115 Add solution properties to manifest if it exists
if ((Test-Path "$SOLUTIONROOT\CDAF.solution") -and ($item -ne $LOCAL_WORK_DIR) -and ($item -ne $REMOTE_WORK_DIR)) {
	Get-Content $SOLUTIONROOT\CDAF.solution | Add-Content manifest.txt
}
Write-Host "`nCreated manifest.txt file ...`n"
Get-Content manifest.txt
write-host "`n[$scriptName] Always create local working artefacts, even if all tasks are remote" -ForegroundColor Blue
executeExpression "& '$AUTOMATIONROOT\buildandpackage\packageLocal.ps1' '$SOLUTION' '$BUILDNUMBER' '$REVISION' '$LOCAL_WORK_DIR' '$SOLUTIONROOT' '$AUTOMATIONROOT'"

# Process optional post-packaging tasks (wrap.tsk added in release 0.8.2)
if (Test-Path "$postpackageTasks") {
	Write-Host "`n[$scriptName] Process Post-Package Tasks ...`n"
	executeExpression "& '$AUTOMATIONROOT\remote\execute.ps1' '$SOLUTION' '$BUILDNUMBER' 'package' '$postpackageTasks' '$ACTION'"
}

# 1.7.8 Only create the remote package if there is a remote target folder or a artefact definition list, if folder exists
# create the remote package (even if there are no target files within it)
# 2.4.0 create remote package for use in container deployment
if (( Test-Path "$containerPropertiesDir" -pathtype container) -or ( Test-Path "$remotePropertiesDir" -pathtype container) -or ( Test-Path "$SOLUTIONROOT\storeForRemote" -pathtype leaf) -or ( Test-Path "$SOLUTIONROOT\storeFor" -pathtype leaf)) {

	executeExpression "& '$AUTOMATIONROOT\buildandpackage\packageRemote.ps1' '$SOLUTION' '$BUILDNUMBER' '$REVISION' '$LOCAL_WORK_DIR' '$REMOTE_WORK_DIR' '$SOLUTIONROOT' '$AUTOMATIONROOT'"

} else {
	write-host "`n[$scriptName] Remote Properties directory ($remotePropertiesDir) or storeForRemote file do not exist, no action performed for remote task packaging" -ForegroundColor Yellow
}

write-host "`n[$scriptName]   --- Package Complete ---" -ForegroundColor Green
