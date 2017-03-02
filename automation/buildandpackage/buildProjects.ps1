# Entry Point for Build Process

$scriptName = $MyInvocation.MyCommand.Name
Write-Host
Write-Host "[$scriptName] +----------------------------+"
Write-Host "[$scriptName] | Process BUILD all projects |"
Write-Host "[$scriptName] +----------------------------+"

$SOLUTION = $args[0]
if (-not($SOLUTION)) {taskFailure "SOLUTION_NOT_PASSED" }
Write-Host "[$scriptName]   SOLUTION       : $SOLUTION"

$BUILDNUMBER = $args[1]
if (-not($BUILDNUMBER)) {taskFailure "BUILDNUMBER_NOT_PASSED" }
Write-Host "[$scriptName]   BUILDNUMBER    : $BUILDNUMBER"

$REVISION = $args[2]
if (-not($REVISION)) {taskFailure "REVISION_NOT_PASSED" }
Write-Host "[$scriptName]   REVISION       : $REVISION"

$AUTOMATIONROOT = $args[3]
if (-not($AUTOMATIONROOT)) {taskFailure "AUTOMATIONROOT_NOT_PASSED" }
Write-Host "[$scriptName]   AUTOMATIONROOT : $AUTOMATIONROOT"

$SOLUTIONROOT = $args[4]
if (-not($SOLUTIONROOT)) {taskFailure "SOLUTIONROOT_NOT_PASSED" }
Write-Host "[$scriptName]   SOLUTIONROOT   : $SOLUTIONROOT"

$ACTION = $args[5]
if ( $ACTION ) {
	if ( $ACTION -eq "clean" ) { # Case insensitive
		Write-Host "[$scriptName]   ACTION         : $ACTION (Environment will use default value)"
	} else {
		$ENVIRONMENT = $ACTION
		Write-Host "[$scriptName]   ACTION         : $ACTION (Not `"clean`", so used for Environment)"
		Write-Host "[$scriptName]   ENVIRONMENT    : $ENVIRONMENT (derived from action)" 
	}
} else {
	Write-Host "[$scriptName]   ACTION         : $ACTION"
}
if (!( $ENVIRONMENT )) {
# Build and Delivery Properties Lookup values
	$ENVIRONMENT = $env:environmentBuild
	if ($ENVIRONMENT ) {
		Write-Host "[$scriptName]   ENVIRONMENT    : $ENVIRONMENT (from `$env:environmentBuild)"
	} else {
		$ENVIRONMENT = 'BUILDER'
		Write-Host "[$scriptName]   ENVIRONMENT    : $ENVIRONMENT (default)"
	}
} 

$automationHelper="$AUTOMATIONROOT\remote"

$exitStatus = 0

# Build a list of projects, based on directory names, unless an override project list file exists
$projectList = ".\$SOLUTIONROOT\buildProjects"
Write-Host –NoNewLine "[$scriptName]   Project list   : " 
pathTest $projectList

write-host 
write-host "[$scriptName] Load solution properties ..."
& .\$automationHelper\Transform.ps1 "$SOLUTIONROOT\CDAF.solution" | ForEach-Object { invoke-expression $_ }

Write-Host 
Write-Host "[$scriptName] Clean temp files and folders from workspace" 
removeTempFiles
itemRemove .\projectDirectories.txt
itemRemove .\projectsToBuild.txt
itemRemove .\*.zip
itemRemove .\*.nupkg

# If there is a custom task in the solution root, execute this.
if (Test-Path build.tsk) {
	Write-Host 
	Write-Host "[$scriptName] build.tsk found in solution root, executing in $(pwd)" 
	Write-Host 
    # Because PowerShell variables are global, set the $WORKSPACE before invoking execution
    $WORKSPACE=$(pwd)
    & .\$automationHelper\execute.ps1 $SOLUTION $BUILDNUMBER $ENVIRONMENT "build.tsk" $ACTION
    if(!$?){ taskFailure("SOLUTION_EXECUTE_${SOLUTION}_${BUILDNUMBER}_${ENVIRONMENT}_build.tsk_${ACTION}") }

} 

# If there is a custom build script in the solution root, execute this.
if (Test-Path build.ps1) {
	Write-Host 
	Write-Host "[$scriptName] build.ps1 found in solution root, executing in $(pwd)" 
	Write-Host 
    # Legacy build method, note: a .BAT file may exist in the project folder for Dev testing, by is not used by the builder
    & .\build.ps1 $SOLUTION $BUILDNUMBER $REVISION $PROJECT $ENVIRONMENT $ACTION
    if(!$?){ taskFailure("SOLUTION_BUILD_${SOLUTION}_${BUILDNUMBER}_${REVISION}_${PROJECT}_${ENVIRONMENT}_${ACTION}") }
}

# Set the projects to process (default is alphabetic)
if (-not(Test-Path $projectList)) {
	foreach ($item in (Get-ChildItem -Path ".")) {
		if (Test-Path $item -PathType "Container") {
			Add-Content projectDirectories.txt $item.Name
		}
	}
} else {
	Copy-Item $projectList projectDirectories.txt
	Set-ItemProperty projectDirectories.txt -name IsReadOnly -value $false
}

# List the projects to process, i.e. only those with build script entry point
Foreach ($PROJECT in get-content projectDirectories.txt) {
	if ((Test-Path .\$PROJECT\build.ps1) -or (Test-Path .\$PROJECT\build.tsk)) {
		Add-Content projectsToBuild.txt $PROJECT
	}
}

if (-not(Test-Path projectsToBuild.txt)) {

	write-host
	write-host "[$scriptName] No project directories found containing build.ps1 or build.tsk, assuming new solution, continuing ... " -ForegroundColor Yellow

} else {

	write-host
	write-host "[$scriptName] Projects to build:"
	write-host
	Get-Content projectsToBuild.txt
	write-host

	# Process all Tasks
	Foreach ($PROJECT in get-content projectsToBuild.txt) {
    
		write-host
		write-host "[$scriptName]   --- Build Project $PROJECT start ---" -ForegroundColor Green
		write-host

		cd $PROJECT

        if (Test-Path build.tsk) {
            # Task driver support added in release 0.6.1
            $WORKSPACE=$(pwd)
		    & ..\$automationHelper\execute.ps1 $SOLUTION $BUILDNUMBER $ENVIRONMENT "build.tsk" $ACTION
		    if(!$?){ taskFailure("PROJECT_EXECUTE_${SOLUTION}_${BUILDNUMBER}_${ENVIRONMENT}_build.tsk_${ACTION}") }

        } else {
            # Legacy build method, note: a .BAT file may exist in the project folder for Dev testing, by is not used by the builder
		    & .\build.ps1 $SOLUTION $BUILDNUMBER $REVISION $PROJECT $ENVIRONMENT $ACTION
		    if(!$?){ taskFailure("PROJECT_BUILD_${SOLUTION}_${BUILDNUMBER}_${REVISION}_${PROJECT}_${ENVIRONMENT}_${ACTION}") }
        }

        cd ..

		write-host
		write-host "[$scriptName]   --- BUILD project $PROJECT successfull ---" -ForegroundColor Green
	} 

}

# Only remove temp files from workspace if action is clean, otherwise leave files for debugging and adit purposes
if ($ACTION -eq "Clean") {
    removeTempFiles
}
