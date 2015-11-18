param(
    [Parameter(Mandatory = $true)]
    $SOLUTION,

    [Parameter(Mandatory = $true)]
    $BUILDNUMBER,

    [Parameter(Mandatory = $true)]
    $REVISION,

    [Parameter(Mandatory = $false)]
    $ENVIRONMENT,

    [Parameter(Mandatory = $false)]
    $AUTOMATIONROOT,

    [Parameter(Mandatory = $false)]
    $ACTION
)


function exitWithCode ($taskName) {
    write-host
    write-host "[$scriptName] $taskName failed!" -ForegroundColor Red
    write-host
    write-host "     Returning errorlevel (-1) to DOS" -ForegroundColor Magenta
    write-host
    $host.SetShouldExit(-1)
    exit
}

function taskWarning { 
    write-host "[$scriptName] Warning, $taskName encountered an error that was allowed to proceed." -ForegroundColor Yellow
}

function itemRemove ($itemPath) { 
	if ( Test-Path $itemPath ) {
		write-host "[$scriptName] Delete $itemPath"
		Remove-Item $itemPath -Recurse 
		if(!$?){ exitWithCode("Remove-Item $itemPath") }
	}
}

function removeTempFiles { 
    if (Test-Path projectsToBuild.txt) {
        Remove-Item projectsToBuild.txt -recurse
    }

    if (Test-Path projectDirectories.txt) {
        Remove-Item projectDirectories.txt -recurse
    }
}

function pathTest ($pathToTest) { 
	if ( Test-Path $pathToTest ) {
		Write-Host "found ($pathToTest)"
	} else {
		Write-Host "none ($pathToTest)"
	}
}

if (-not($SOLUTION)) {exitWithCode SOLUTION_NOT_PASSED }
if (-not($BUILDNUMBER)) {exitWithCode BUILDNUMBER_NOT_PASSED }
if (-not($REVISION)) {exitWithCode REVISION_NOT_PASSED }
if (-not($ENVIRONMENT)) {
	$ENVIRONMENT = "DEV"
	Write-Host "[$scriptName]   Environment not passed, defaulted to $ENVIRONMENT" 
}

$automationHelper="$AUTOMATIONROOT\remote"

$exitStatus = 0

$scriptName = $MyInvocation.MyCommand.Name

Write-Host "[$scriptName]   AUTOMATIONROOT : $AUTOMATIONROOT" 

$projectList = ".\$AUTOMATIONROOT\solution\buildProjects"

Write-Host –NoNewLine "[$scriptName]   Project list   : " 
pathTest $projectList

$propertiesFile = "$AUTOMATIONROOT\CDAF.windows"
$propName = "productVersion"
try {
	$cdafVersion=$(& .\$AUTOMATIONROOT\remote\getProperty.ps1 $propertiesFile $propName)
	if(!$?){ taskWarning }
} catch { exitWithCode "PACK_GET_CDAF_VERSION" }
Write-Host "[$scriptName]   CDAF Version   : $cdafVersion"

Write-Host 
Write-Host "[$scriptName] Clean temp files and folders from workspace" 
removeTempFiles
itemRemove .\*.txt
itemRemove .\*.zip
itemRemove .\*.nupkg

# Check for user defined solution folder, i.e. outside of automation root, if found override solution root
$solutionRoot="$AUTOMATIONROOT\solution"

foreach ($item in (Get-ChildItem -Path ".")) {
	if ($item.Attributes -eq "Directory") {
		if (Test-Path "$item\CDAF.solution") {
			write-host 
			write-host "[$scriptName] CDAF.solution file found in directory `"$item`", load solution properties"
			$solutionRoot=$item
			& .\$automationHelper\Transform.ps1 "$item\CDAF.solution" | ForEach-Object { invoke-expression $_ }
		}
	}
}

# Build a list of projects, base on directory names unless an override project list file exists
if (-not(Test-Path $projectList)) {
	foreach ($item in (Get-ChildItem -Path ".")) {
		if ($item.Attributes -eq "Directory") {
			Add-Content projectDirectories.txt $item.Name
		}
	}
} else {
	write-host
    write-host "[$scriptName] Using override Project list ($projectList)" -ForegroundColor Yellow
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
	write-host

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
		    if(!$?){ exitWithCode(".,\$automationHelper\execute.ps1 $SOLUTION $BUILDNUMBER $ENVIRONMENT `"build.tsk`" $ACTION") }

        } else {
            # Legacy build method, note: a .BAT file may exist in the project folder for Dev testing, by is not used by the builder
		    & .\build.ps1 $SOLUTION $BUILDNUMBER $REVISION $PROJECT $ENVIRONMENT $ACTION
		    if(!$?){ exitWithCode("& .\build.ps1 $SOLUTION $BUILDNUMBER $REVISION $PROJECT $ENVIRONMENT $ACTION") }
        }

        cd ..

		write-host
		write-host "[$scriptName]   --- BUILD project $PROJECT successfull ---" -ForegroundColor Green
		write-host
	} 

}

# Only remove temp files from workspace if action is clean, otherwise leave files for debugging and adit purposes
if ($ACTION -eq "Clean") {
    removeTempFiles
}
