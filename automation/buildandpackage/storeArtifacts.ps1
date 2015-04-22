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
	$ENVIRONMENT = "DEV"
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

$artifactListFile=".\$AUTOMATIONROOT\solution\storeForArtifact"
$DTSTAMP = Get-Date
$typeDirectory = 'Directory';
$typeFile = 'File';
$zaSourcePath = ".\$AUTOMATIONROOT\provisioning\za.exe";
$zaPath = '.\za.exe';

if ($ACTION -eq 'Clean')
{
    # Cannot brute force clear the workspace as the Visual Studio solution file is here
    write-host
    write-host "[$scriptName]   --- Cleaning Artifact Store ---" -ForegroundColor Green
    
    if ( Test-Path $ARTIFACT_WORKBENCH )
    {
		Remove-Item $ARTIFACT_WORKBENCH -Recurse
		if(!$?) {exitWithCode "Remove-Item $ARTIFACT_WORKBENCH -Recurse" }
	}

    if ( Test-Path $zaPath )
    {
        Remove-Item $zaPath;
		if(!$?) {exitWithCode "Test-Path $zaPath" }
    }

    write-host
    write-host "[$scriptName]   --- Artifact Store Cleanup Complete ---" -ForegroundColor Green
}
else
{
    # Cannot brute force clear the workspace as the Visual Studio solution file is here
    write-host
    write-host "[$scriptName]   --- Building Artifact Store ---" -ForegroundColor Green
    
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

            # Get the zip application ready for use.
            # Note: We can't store this in the workbench because someone might want to zip the workbench itself.
            #       If they did, this could grab za itself and include it in the zip, which is not desired. For
            #       this reason, za.exe will be executed from the solution root.
            if ( -not ( Test-Path $zaPath ) )
            {
                Copy-Item $zaSourcePath -Destination $zaPath -Force;
            }

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
                
                if ($artifactOptions.Length -ge 2)
                {
                    $target = $artifactOptions[1].Trim();
                }
                else
                {
                    $target = $null;
                }

                if ($artifactOptions.Length -ge 3)
                {
                    $typeTarget = $artifactOptions[3].Trim();
                }
                else
                {
                    $typeTarget = $null;
                }

                if (-not $target)
                {
                    $targetPath = $ARTIFACT_WORKBENCH;
                }
                else
                {
                    $targetPath = "$ARTIFACT_WORKBENCH\$target";
                }
                
                if ($typeTarget -eq $null)
                {
                    if (isFilePath($targetPath))
                    {
                        $typeTarget = $typeFile;
                    }
                    else
                    {
                        $typeTarget = $typeDirectory;
                    }
                }

                if (isFilePath($artifactFile))
                {
                    $typeArtifact = $typeFile;
                }
                else
                {
                    $typeArtifact = $typeDirectory;
                }
                
                Write-Host "[$scriptName] $artifactFile ($typeArtifact) -> $targetPath ($typeTarget)";

                if (($artifactFile.StartsWith($ARTIFACT_WORKBENCH)) -and ($typeArtifact -eq $typeDirectory))
                {
                    # A subdirectory of the $ARTIFACT_WORKBENCH has been submitted. This indicates we should
                    # zip the listed subdirectory and store it in the $targetPath.
                    
                    # New-item to create any required directories.
                    New-Item $targetPath -Force -ItemType $typeTarget > $null;
		            if(!$?){ exitWithCode ("New-Item $targetPath -Force -ItemType $typeTarget") }

                    # Now remove the zip file itself to make room for 7zip.
                    Remove-Item $targetPath -Force > $null
		            if(!$?){ exitWithCode ("New-Item $targetPath -Force -ItemType $typeTarget") }

                    # Now we can actualy build and invoke the Zip Command.
                    $fullPath = Convert-Path $artifactFile;
                    $zipCommand = "& $zaPath a $targetPath $fullPath\*"

                    Write-Host "[$scriptName] $zipCommand" -ForegroundColor Cyan;
                    Invoke-Expression $zipCommand;
		            if(!$?){ exitWithCode ("Invoke-Expression $zipCommand") }
                }
                else
                {
                    New-Item $targetPath -Force -ItemType $typeTarget > $null;
		            if(!$?){ exitWithCode ("New-Item $targetPath -Force -ItemType $typeTarget") }

                    Copy-Item $artifactFile -Destination $targetPath -Recurse -Force;
		            if(!$?){ exitWithCode ("Copy-Item $artifactFile -Destination $targetPath -Recurse -Force") }
                }
            }

            if ( Test-Path $zaPath )
            {
                Remove-Item $zaPath;
		        if(!$?) {exitWithCode "Test-Path $zaPath" }
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

