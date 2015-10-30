function exitWithCode($taskName) {
    write-host
    write-host "[$scriptName] Caught an exception excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    write-host
    write-host "     Returning errorlevel (-1) to DOS" -ForegroundColor Magenta
    write-host
    $host.SetShouldExit(-1)
    exit
}

function taskComplete { 
    write-host
    write-host "[$scriptName] Remote Task ($taskName) Successfull " -ForegroundColor Green
    write-host
}

function taskWarning($taskName) { 
    write-host
    write-host "[$scriptName] Warning, $taskName encountered an error that was allowed to proceed." -ForegroundColor Yellow
}

function itemRemove ($itemPath) { 
# If item exists, and is a directory, recursively remove hidden and read-only attributes or to explicit file name if just a file 
	if ( Test-Path $itemPath ) {
		if ( (Get-Item $itemPath) -is [System.IO.DirectoryInfo] ) {
			attrib -r -h *.* /s /d
		} else {
			attrib -r -h $itemPath /s
		}	
		write-host "[$scriptName] Delete $itemPath"
		Remove-Item $itemPath -Recurse
		if(!$?) {exitWithCode "Remove-Item $itemPath -Recurse" }
	}
}

function getFilename ($FullPathName) {

	$PIECES=$FullPathName.split(“\”) 
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
			copySet $item $sourceDir $targetDir
		} else {
			copySet $item $sourceDir $targetDir\$dirName
		}
	}
}

function copySet ($item, $from, $to) {

	Write-Host "[$scriptName]   $from\$item --> $to" 
	Copy-Item $from\$item $to -Force
	if(!$?){ taskFailure ("Copy remote script $from\$item --> $to") }
	Set-ItemProperty $to\$item -name IsReadOnly -value $false
	if(!$?){ taskFailure ("remove read only from $to\$item") }
	
}

$SOLUTION = $args[0]
$BUILDNUMBER = $args[1]
$REVISION = $args[2]
$LOCAL_WORK_DIR = $args[3]
$REMOTE_WORK_DIR = $args[4]
$AUTOMATIONROOT=$args[5]
$ACTION = $args[6]

if (-not($SOLUTION)) {exitWithCode SOLUTION_NOT_PASSED }
if (-not($BUILDNUMBER)) {exitWithCode BUILDNUMBER_NOT_PASSED }
if (-not($REVISION)) {exitWithCode REVISION_NOT_PASSED }
if (-not($LOCAL_WORK_DIR)) {exitWithCode LOCAL_NOT_PASSED }
if (-not($REMOTE_WORK_DIR)) {exitWithCode REMOTE_NOT_PASSED }

$scriptName = $MyInvocation.MyCommand.Name

Write-Host "[$scriptName]   AUTOMATIONROOT          : $AUTOMATIONROOT" 
$automationHelper="$AUTOMATIONROOT\remote"
Write-Host "[$scriptName]   automationHelper        : $automationHelper" 

# Check for user defined solution folder, i.e. outside of automation root, if found override solution root
$solutionRoot="$AUTOMATIONROOT\solution"
foreach ($item in (Get-ChildItem -Path ".")) {
	if ($item.Attributes -eq "Directory") {
		if (Test-Path "$item\CDAF.solution") {
			$solutionRoot=$item
		}
	}
}
Write-Host "[$scriptName]   solutionRoot            : $solutionRoot" 

$prepackageTasks = "$solutionRoot\package.tsk"
Write-Host –NoNewLine "[$scriptName]   Prepackage Tasks        : " 
if (Test-Path "$prepackageTasks") {
	Write-Host "found ($prepackageTasks)"
} else {
	Write-Host "none ($prepackageTasks)"
}

$postpackageTasks = "$solutionRoot\wrap.tsk"
Write-Host –NoNewLine "[$scriptName]   Postpackage Tasks       : " 
if (Test-Path "$postpackageTasks") {
	Write-Host "found ($postpackageTasks)"
} else {
	Write-Host "none ($postpackageTasks)"
}

# Test for optional properties
$remotePropertiesDir = "$solutionRoot\propertiesForRemoteTasks"
Write-Host –NoNewLine "[$scriptName]   Remote Target Directory : " 

if ( Test-Path $remotePropertiesDir ) {
	Write-Host "found ($remotePropertiesDir)"
} else {
	Write-Host "none ($remotePropertiesDir)"
}

Write-Host "[$scriptName]   user name               : $(whoami)" 

# Cannot brute force clear the workspace as the Visual Studio solution file is here
write-host
write-host "[$scriptName]   --- Start Package Process ---" -ForegroundColor Green
Write-Host
itemRemove .\*.txt
itemRemove .\*.zip
itemRemove .\*.nupkg
itemRemove $LOCAL_WORK_DIR
itemRemove $REMOTE_WORK_DIR

if ( $ACTION -eq "clean" ) {

	Write-Host
	write-host "[$scriptName] Clean only." -ForegroundColor Blue

} else {

	# Process solution properties if defined
	if ((Test-Path "$solutionRoot\CDAF.solution") -and ($item -ne $LOCAL_WORK_DIR) -and ($item -ne $REMOTE_WORK_DIR)) {
		write-host 
		write-host "[$scriptName] CDAF.solution file found in directory `"$item`", load solution properties"
		& .\$automationHelper\Transform.ps1 "$solutionRoot\CDAF.solution" | ForEach-Object { invoke-expression $_ }
	}

	# Process optional pre-packaging tasks (Task driver support added in release 0.7.2)
    if (Test-Path "$prepackageTasks") {
		Write-Host
		Write-Host "Process Pre-Package Tasks ..."
		& .\$automationHelper\execute.ps1 $SOLUTION $BUILDNUMBER "package" "$prepackageTasks" $ACTION
		if(!$?){ exitWithCode "..\$automationHelper\execute.ps1 $SOLUTION $BUILDNUMBER `"package`" `"$prepackageTasks`" $ACTION" }
	}

	# Load Manifest, these properties are used by remote deployment
	Add-Content manifest.txt "# Manifest for revision $REVISION"
	Add-Content manifest.txt "SOLUTION=$SOLUTION"
	Add-Content manifest.txt "BUILDNUMBER=$BUILDNUMBER"
	Write-Host
	write-host "[$scriptName] Always create local working artefacts, even if all tasks are remote" -ForegroundColor Blue
	try {
		& .\$AUTOMATIONROOT\buildandpackage\packageLocal.ps1 $SOLUTION $BUILDNUMBER $REVISION $LOCAL_WORK_DIR $solutionRoot $AUTOMATIONROOT
		if(!$?){ taskWarning }
	} catch { exitWithCode("packageLocal.ps1") }

	if ( -not( Test-Path $remotePropertiesDir ) ) {

		write-host "[$scriptName] Remote Properties directory ($remotePropertiesDir) does not exist, no action performed for remote task packaging" -ForegroundColor Yellow

	} else {
	
		try {
			& .\$AUTOMATIONROOT\buildandpackage\packageRemote.ps1 $SOLUTION $BUILDNUMBER $REVISION $LOCAL_WORK_DIR $REMOTE_WORK_DIR $solutionRoot $AUTOMATIONROOT
			if(!$?){ taskWarning }
		} catch { exitWithCode("packageRemote.ps1") }
	}

	# Process optional post-packaging tasks (wrap.tsk added in release 0.8.2)
    if (Test-Path "$postpackageTasks") {
		Write-Host
		Write-Host "Process Post-Package Tasks ..."
		& .\$automationHelper\execute.ps1 $SOLUTION $BUILDNUMBER "package" "$postpackageTasks" $ACTION
		if(!$?){ exitWithCode "..\$automationHelper\execute.ps1 $SOLUTION $BUILDNUMBER `"package`" `"$postpackageTasks`" $ACTION" }
	}

}
write-host
write-host "[$scriptName]   --- Package Complete ---" -ForegroundColor Green
