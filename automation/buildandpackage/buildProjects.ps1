
function removeTempFiles {
	$itemList = @("*.zip", "*.tar.gz", "*.nupkg")
	foreach ($itemName in $itemList) {  
		itemRemove ".\${itemName}"
    }
}

$projectDirectories = @()
$projectsToBuild = @()

$scriptName = $MyInvocation.MyCommand.Name
Write-Host "`n[$scriptName] +----------------------------+"
Write-Host "[$scriptName] | Process BUILD all projects |"
Write-Host "[$scriptName] +----------------------------+"

$SOLUTION = $args[0]
if (-not($SOLUTION)) { ERRMSG "SOLUTION_NOT_PASSED" 100 }
Write-Host "[$scriptName]   SOLUTION          : $SOLUTION"

$BUILDNUMBER = $args[1]
if (-not($BUILDNUMBER)) { ERRMSG "BUILDNUMBER_NOT_PASSED" 101 }
Write-Host "[$scriptName]   BUILDNUMBER       : $BUILDNUMBER"

$REVISION = $args[2]
if (-not($REVISION)) { ERRMSG "REVISION_NOT_PASSED" 102 }
Write-Host "[$scriptName]   REVISION          : $REVISION"

$AUTOMATIONROOT = $args[3]
if (-not($AUTOMATIONROOT)) { ERRMSG "AUTOMATIONROOT_NOT_PASSED" 103 }
Write-Host "[$scriptName]   AUTOMATIONROOT    : $AUTOMATIONROOT"

$SOLUTIONROOT = $args[4]
if (-not($SOLUTIONROOT)) { ERRMSG "SOLUTIONROOT_NOT_PASSED" 104 }
Write-Host "[$scriptName]   SOLUTIONROOT      : $SOLUTIONROOT"

$ACTION = $args[5]
if ( $ACTION ) {
	if ( $ACTION -eq "clean" ) { # Case insensitive
		Write-Host "[$scriptName]   ACTION            : $ACTION (Environment will use default value)"
	} else {
		Write-Host "[$scriptName]   ACTION            : $ACTION (Not `"clean`", so used for Environment)"
	}
} else {
	Write-Host "[$scriptName]   ACTION            : $ACTION"
}

# BUILDENV determined by buildPackage, no longer ambiguous "ENVIRONMENT" variable
Write-Host "[$scriptName]   BUILDENV          : $BUILDENV"

$automationHelper="$AUTOMATIONROOT\remote"

# Build a list of projects, based on directory names, unless an override project list file exists
$projectList = "$SOLUTIONROOT\buildProjects"
Write-Host -NoNewLine "[$scriptName]   Project list      : " 
pathTest $projectList

write-host "`n[$scriptName] Load solution properties ..."
& $automationHelper\Transform.ps1 "$SOLUTIONROOT\CDAF.solution" | ForEach-Object { invoke-expression $_ }

Write-Host "`n[$scriptName] Clean temp files and folders from workspace" 
removeTempFiles

# If there is a custom task in the solution root, execute this.
if (Test-Path build.tsk) {
	Write-Host "`n[$scriptName] build.tsk found in solution root, executing in $(pwd)`n" 
    # Because PowerShell variables are global, set the $WORKSPACE before invoking execution
    $WORKSPACE=$(pwd)
    & $automationHelper\execute.ps1 $SOLUTION $BUILDNUMBER $BUILDENV "build.tsk" $ACTION
	if($LASTEXITCODE -ne 0){ ERRMSG "ROOT_EXECUTE_NON_ZERO_EXIT $automationHelper\execute.ps1 $SOLUTION $BUILDNUMBER $BUILDENV build.tsk $ACTION" $LASTEXITCODE }
    if(!$?){ taskFailure "SOLUTION_EXECUTE_${SOLUTION}_${BUILDNUMBER}_${ENVIRONMENT}_build.tsk_${ACTION}" }
} 

# If there is a custom build script in the solution root, execute this.
if (Test-Path build.ps1) {
	Write-Host "`n[$scriptName] build.ps1 found in solution root, executing in $(pwd)`n" 
    # Legacy build method, note: a .BAT file may exist in the project folder for Dev testing, by is not used by the builder
    try {
	    & .\build.ps1 $SOLUTION $BUILDNUMBER $REVISION ROOT $BUILDENV $ACTION
		if($LASTEXITCODE -ne 0){ ERRMSG "ROOT_LEGACY_NON_ZERO_EXIT .\build.ps1 $SOLUTION $BUILDNUMBER $REVISION ROOT $BUILDENV $ACTION" $LASTEXITCODE }
	    if(!$?){ taskFailure "SOLUTION_BUILD_${SOLUTION}_${BUILDNUMBER}_${REVISION}_ROOT_${ENVIRONMENT}_${ACTION}" }
    } catch {
	    write-host "[$scriptName] CUSTOM_BUILD_EXCEPTION & .\build.ps1 $SOLUTION $BUILDNUMBER $REVISION ROOT $BUILDENV $ACTION" -ForegroundColor Magenta
    	exceptionExit $_
    }
}

# Set the projects to process (default is alphabetic)
if (Test-Path $projectList) {
	$projectDirectories = Get-Content -Path $projectList
} else {
	foreach ($item in (Get-ChildItem -Path ".")) {
		if (Test-Path $item -PathType "Container") {
			$projectDirectories += $item.Name
		}
	}
}

# List the projects to process, i.e. only those with build script entry point
foreach ($directory in $projectDirectories ) {
	if ((Test-Path .\$directory\build.ps1) -or (Test-Path .\$directory\build.tsk)) {
		$projectsToBuild += $directory
	}
}

if (-not($projectsToBuild)) {

	write-host "`n[$scriptName] No project directories found containing build.ps1 or build.tsk, assuming new solution, continuing ... " -ForegroundColor Yellow

} else {

	write-host "`n[$scriptName] Projects to build:`n"
	$projectsToBuild

	# Process all Tasks
	foreach (${PROJECT} in $projectsToBuild) {
    
		write-host "`n[$scriptName]   --- Build Project ${PROJECT} start ---`n" -ForegroundColor Green

		cd ${PROJECT}

        if (Test-Path build.tsk) {
            # Task driver support added in release 0.6.1
            $WORKSPACE=$(pwd)
		    & $automationHelper\execute.ps1 $SOLUTION $BUILDNUMBER $BUILDENV "build.tsk" $ACTION
			if($LASTEXITCODE -ne 0){ ERRMSG "PROJECT_EXECUTE_NON_ZERO_EXIT & $automationHelper\execute.ps1 $SOLUTION $BUILDNUMBER $BUILDENV build.tsk $ACTION" $LASTEXITCODE }
		    if(!$?){ taskFailure "PROJECT_EXECUTE_${SOLUTION}_${BUILDNUMBER}_${ENVIRONMENT}_build.tsk_${ACTION}" }

        } else {
            # Legacy build method, note: a .BAT file may exist in the project folder for Dev testing, by is not used by the builder
		    & .\build.ps1 $SOLUTION $BUILDNUMBER $REVISION ${PROJECT} $BUILDENV $ACTION
			if($LASTEXITCODE -ne 0){ ERRMSG "PROJECT_EXECUTE_NON_ZERO_EXIT .\$automationHelper\execute.ps1 $SOLUTION $BUILDNUMBER $BUILDENV build.tsk $ACTION" $LASTEXITCODE }
		    if(!$?){ taskFailure "PROJECT_BUILD_${SOLUTION}_${BUILDNUMBER}_${REVISION}_${PROJECT}_${ENVIRONMENT}_${ACTION}" }
        }

        cd ..

		write-host "`n[$scriptName]   --- BUILD project ${PROJECT} successfull ---" -ForegroundColor Green
	} 

}

# Only remove temp files from workspace if action is clean, otherwise leave files for debugging and adit purposes
if ($ACTION -eq "Clean") {
    removeTempFiles
}
