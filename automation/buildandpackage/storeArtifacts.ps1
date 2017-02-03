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

function pathTest ($pathToTest) {
    if ( Test-Path $pathToTest ) {
        Write-Host "found ($pathToTest)"
    } else {
        Write-Host "none ($pathToTest)"
    }
}

function isFilePath ($path)
{
    $tokens = $path.split('\');
    $finalToken = $tokens[$tokens.Count - 1];

    if ($finalToken.Contains('.'))
    {
        return $true;
    }
    else
    {
        return $false;
    }
}

if (-not($SOLUTION)) {exitWithCode SOLUTION_NOT_SET }
if (-not($BUILDNUMBER)) {exitWithCode BUILDNUMBER_NOT_SET }
if (-not($REVISION)) {exitWithCode REVISION_NOT_SET }
if (-not($AUTOMATIONROOT)) {exitWithCode AUTOMATIONROOT_NOT_SET }
if (-not($SOLUTIONROOT)) {exitWithCode SOLUTIONROOT_NOT_SET }
if (-not($ENVIRONMENT)) {
    $ENVIRONMENT = "PACKAGE"
    Write-Host "[$scriptName]   Environment not passed, defaulted to $ENVIRONMENT"
}

$scriptName = $MyInvocation.MyCommand.Name

# Properties file loader, all properties are instantiated as runtime variables and listed in the logs
Invoke-Expression ".\$AUTOMATIONROOT\remote\Transform.ps1 $SOLUTIONROOT\propertiesForLocalTasks\$ENVIRONMENT" | ForEach-Object { invoke-expression $_ }

if (-not $ARTIFACT_WORKBENCH)
{
    Write-Host;
    Write-Host "[$scriptName] ARTIFACT_WORKBENCH not found in $ENVIRONMENT properties, defaulting to 'artifacts'";
    $ARTIFACT_WORKBENCH = 'artifacts';
}

$artifactListFile=".\$SOLUTIONROOT\storeForArtifact"
$DTSTAMP = Get-Date
$typeDirectory = 'Directory';
$typeFile = 'File';
$zaFilename = '7za.exe';

# Cannot brute force clear the workspace as the Visual Studio solution file is here
write-host
write-host "[$scriptName]   --- Building Artifact Store ---" -ForegroundColor Green

if ($ACTION -eq 'Clean')
{
    if ( Test-Path $ARTIFACT_WORKBENCH -Verbose )
    {
        Remove-Item $ARTIFACT_WORKBENCH -Recurse
        if(!$?) {exitWithCode "Remove-Item $ARTIFACT_WORKBENCH -Recurse" }
    }

    write-host
    write-host "[$scriptName]   --- Artifact Store Cleanup Complete ---" -ForegroundColor Green
}
else
{

    if ( Test-Path $ARTIFACT_WORKBENCH )
    {
        Remove-Item $ARTIFACT_WORKBENCH -Recurse;
        if(!$?) {exitWithCode "Remove-Item $ARTIFACT_WORKBENCH -Recurse" }
    }

    write-host –NoNewLine "[$scriptName] Artifact List: "
    pathTest $artifactListFile

    # Create the workspace directory
    New-Item $ARTIFACT_WORKBENCH -type directory > $null
    if(!$?){ exitWithCode ("New-Item $ARTIFACT_WORKBENCH -type directory > $null") }

    # Copy artifacts if list file exists
    if ( Test-Path $artifactListFile )
    {
        $hasItems = $false;

        $artifactList = get-content $artifactListFile;

        if ($artifactList.Length -le 0)
        {
            Write-Host
            Write-Host "[$scriptName] Artifact List File ($artifactListFile) exists but has no content. No files will be moved to $ARTIFACT_WORKBENCH" -ForegroundColor Yellow
        }
        else
        {
            Write-Host

            foreach ($artifactItem in $artifactList)
            {
                if (-not $artifactItem)
                {
                    continue;
                }

                if ([string]::IsNullOrWhiteSpace($artifactItem))
                {
                    continue;
                }

                if (($artifactItem.StartsWith("[")) -or ($artifactItem.StartsWith("#")))
                {
                    continue;
                }

                $hasItems = $true;

                # Split on pipes
                $artifactOptions = $artifactItem.Split("|");

                $artifactFile = $artifactOptions[0].Trim();

                if ($artifactFile.EndsWith(' -d'))
                {
                    $artifactType = $typeDirectory;
                    $artifactFile = $artifactFile.Substring(0, $artifactFile.Length - 3);
                }
                elseif ($artifactFile.EndsWith(' -f'))
                {
                    $artifactType = $typeFile;
                    $artifactFile = $artifactFile.Substring(0, $artifactFile.Length - 3);
                }
                elseif (isFilePath($artifactFile))
                {
                    $artifactType = $typeFile;
                }
                else
                {
                    $artifactType = $typeDirectory;
                }

                if ($artifactOptions.Length -ge 2)
                {
                    $target = $artifactOptions[1].Trim();

                    if ($target.EndsWith(' -d'))
                    {
                        $targetType = $typeDirectory;
                        $target = $target.Substring(0, $target.Length - 3);
                    }
                    elseif ($target.EndsWith(' -f'))
                    {
                        $targetType = $typeFile;
                        $target = $target.Substring(0, $target.Length - 3);
                    }
                    elseif (isFilePath($target))
                    {
                        $targetType = $typeFile;
                    }
                    else
                    {
                        $targetType = $typeDirectory;
                    }
                }
                else
                {
                    $target = $null;
                    $targetType = $null;
                }

                if (-not $target)
                {
                    $targetPath = $ARTIFACT_WORKBENCH;
                }
                else
                {
                    $targetPath = "$ARTIFACT_WORKBENCH\$target";
                }

                Write-Host "[$scriptName] $artifactFile ($artifactType) -> $targetPath ($targetType)";

                if (($artifactFile.StartsWith($ARTIFACT_WORKBENCH)) -and ($artifactType -eq $typeDirectory))
                {
                    # A subdirectory of the $ARTIFACT_WORKBENCH has been submitted. This indicates we should
                    # zip the listed subdirectory and store it in the $targetPath.

                    # New-item to create any required directories.
                    New-Item $targetPath -Force -ItemType $targetType > $null;
                    if(!$?){ exitWithCode ("New-Item $targetPath -Force -ItemType $targetType") }

                    # Now remove the zip file itself to make room for 7zip.
                    Remove-Item $targetPath -Force > $null
                    if(!$?){ exitWithCode ("New-Item $targetPath -Force -ItemType $targetType") }

                    # Now we can actually build and invoke the Zip Command.
                    $fullPath = Convert-Path $artifactFile;
                    $zipCommand = "& $zaFilename a $targetPath $fullPath\*"

                    Write-Host "[$scriptName] $zipCommand" -ForegroundColor Cyan;
                    Invoke-Expression $zipCommand;
                    if(!$?){ exitWithCode ("Invoke-Expression $zipCommand") }
                }
                else
                {
                    New-Item $targetPath -Force -ItemType $targetType > $null;
                    if(!$?){ exitWithCode ("New-Item $targetPath -Force -ItemType $targetType") }

                    Copy-Item $artifactFile -Destination $targetPath -Recurse -Force -Verbose;
                    if(!$?){ exitWithCode ("Copy-Item $artifactFile -Destination $targetPath -Recurse -Force") }
                }
            }

            if (-not $hasItems)
            {
                Write-Host
                Write-Host "[$scriptName] Artifact List File ($artifactListFile) exists but contains no items. No files will be moved to $ARTIFACT_WORKBENCH" -ForegroundColor Yellow
            }
        }
    }
    else
    {
        Write-Host
        Write-Host "[$scriptName] Artifact List File ($artifactListFile) does not exist. No files will be moved to $ARTIFACT_WORKBENCH" -ForegroundColor Yellow
    }

    write-host
    write-host "[$scriptName]   --- Artifact Store Complete ---" -ForegroundColor Green
}

