Param (
	[string]$BUILDNUMBER,
	[string]$BRANCH,
	[string]$ACTION,
	[string]$AUTOMATIONROOT
)

Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Security

cmd /c "exit 0"
$error.clear()
$scriptName = 'entry.ps1'

# Consolidated Error processing function
function errorClear ($message, $exitcode) {
	if ( $exitcode ) {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Red
	} else {
		Write-Host "`n[$scriptName]$message" -ForegroundColor Yellow
	}
	if ( $error ) {
		$i = 0
		foreach ( $item in $Error )
		{
			Write-Host "`$Error[$i] $item"
			$i++
		}
		$Error.clear()
	}
	if ( $exitcode ) {
		Write-Host "`n[$scriptName] Exit with LASTEXITCODE = $exitcode`n" -ForegroundColor Red
		exit $exitcode
	}
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression "$expression"
	    if(!$?) { errorClear "[TRAP] `$? = $?" 1211 }
	} catch {
		$message = $_.Exception.Message
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
			errorClear "[EXCEPTION] $message" $LASTEXITCODE
		} else {
			errorClear "[EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			errorClear "[EXIT]" $LASTEXITCODE
		} else {
			if ( $error ) {
				errorClear "[WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				errorClear "[ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				errorClear "[WARN] `$LASTEXITCODE not set, but standard error populated"
	    	}
		}
	}
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeSuppress ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression "$expression"
	    if(!$?) { errorClear "[TRAP] `$? = $?" }
	} catch {
		errorClear "[EXCEPTION] ScriptStackTrace"
		Write-Host $_.ScriptStackTrace -Foreground "DarkGray"
		$message = $_.Exception.Message
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
			errorClear "[EXCEPTION] $message"
		} else {
			errorClear "[EXCEPTION] $message"
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			errorClear "[EXIT] $LASTEXITCODE"
		} else {
			if ( $error ) {
				errorClear "[WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
			errorClear "[WARN] `$LASTEXITCODE not set, but standard error populated"
		}
	}
}

function mask ($value) {
	return (Get-FileHash -InputStream $([IO.MemoryStream]::new([byte[]][char[]]$value)) -Algorithm MD5).Hash
}

if (!( $env:CDAF_COMMAND_SHELL )) {
	Write-Host "`n[$scriptName] ----------------------------------"
}

Write-Host "[$scriptName]     Start PowerShell Execution"
Write-Host "[$scriptName] ----------------------------------"
if ($BUILDNUMBER) {
    Write-Host "[$scriptName]   BUILDNUMBER    : $BUILDNUMBER"
} else {

	$counterFile = "$env:USERPROFILE\buildnumber.counter"
	# Use a simple text file ($counterFile) for incrimental build number, using the same logic as cdEmulate.ps1
	if ( Test-Path "$counterFile" ) {
		$buildNumber = Get-Content "$counterFile"
	} else {
		$buildNumber = 0
	}
	[int]$buildnumber = [convert]::ToInt32($buildNumber)
	if ( $ACTION -ne "cdonly" ) { # Do not incriment when just deploying
		$buildNumber += 1
	}
	Set-Content "$counterFile" "$BUILDNUMBER"
    Write-Host "[$scriptName]   BUILDNUMBER    : $BUILDNUMBER (not supplied, generated from local counter file)"
}

if ($BRANCH) {
	if ( $BRANCH.contains('$')) {
		$BRANCH = Invoke-Expression "Write-Output $BRANCH"
	}
    Write-Host "[$scriptName]   BRANCH         : $BRANCH"
} else {
	if ( $env:CDAF_BRANCH_NAME ) {
		$branch = $env:CDAF_BRANCH_NAME
		$skipBranchCleanup = 'yes'
	    Write-Host "[$scriptName]   BRANCH         : $BRANCH (not supplied, derived from `$env:CDAF_BRANCH_NAME)"
	} else {
		$BRANCH=$(git rev-parse --abbrev-ref HEAD)
		if ($BRANCH) {
			Write-Host "[$scriptName]   BRANCH         : $BRANCH (determined from workspace)"
		} else {
			$BRANCH = 'targetlesscd'
			Write-Host "[$scriptName]   BRANCH         : $BRANCH (not supplied, set to default)"
		}
	}
}
if ( $BRANCH -match '/' ) {
	$branchBase = $BRANCH.Split('/')[-1]
} else {
	$branchBase = $BRANCH
}
$BRANCH = ($branchBase -replace '[^a-zA-Z0-9]', '').ToLower()

if ($ACTION) {
	if ( $ACTION.contains('$')) {
		$ACTION = Invoke-Expression "Write-Output $ACTION"
	}
    Write-Host "[$scriptName]   ACTION         : $ACTION"
} else {
    Write-Host "[$scriptName]   ACTION         : (not passed)"
}

if ($AUTOMATIONROOT) {
    Write-Host "[$scriptName]   AUTOMATIONROOT : $AUTOMATIONROOT"
} else {
	$AUTOMATIONROOT = split-path -parent $MyInvocation.MyCommand.Definition
    Write-Host "[$scriptName]   AUTOMATIONROOT : $AUTOMATIONROOT (not supplied, derived from invocation)"
}
$env:CDAF_AUTOMATION_ROOT = $AUTOMATIONROOT


# Check for user defined solution folder, i.e. outside of automation root, if found override solution root
Write-Host "[$scriptName]   SOLUTIONROOT   : " -NoNewline
foreach ($item in (Get-ChildItem -Path ".")) {
	if (Test-Path $item -PathType "Container") {
		if (Test-Path "$item\CDAF.solution") {
			$SOLUTIONROOT = $item.FullName
		}
	}
}

if ($SOLUTIONROOT) {
	write-host "$SOLUTIONROOT (override CDAF.solution found)"
} else {
	$SOLUTIONROOT="$AUTOMATIONROOT\solution"
	write-host "$SOLUTIONROOT (default, project directory containing CDAF.solution not found)"
}
$SOLUTIONROOT = (Get-Item $SOLUTIONROOT).FullName

$automationHelper = "$AUTOMATIONROOT\remote"
& $automationHelper\Transform.ps1 "$SOLUTIONROOT\CDAF.solution" | ForEach-Object { invoke-expression "$_" }

# check for DOS variable and load as PowerShell environment variable
if ($CDAF_DELIVERY) { $environment = "$CDAF_DELIVERY" }
if ($Env:CDAF_DELIVERY) { $environment = "$Env:CDAF_DELIVERY" }
if ($environment) {
    Write-Host "`n[$scriptName]   environment    : $environment (from CDAF_DELIVERY environment variable)"
} else {
	if ( $defaultEnvironment ) {
		$environment = Invoke-Expression "Write-Output $defaultEnvironment"
	    Write-Host "`n[$scriptName]   environment    : $environment (loaded defaultEnvironment property)"
	} else {
		$environment = 'DOCKER'
	    Write-Host "`n[$scriptName]   environment    : $environment (not set, default applied)"
	}
}

if ( ${solutionName} ) {
	$SOLUTION = $solutionName
	Write-Host "[$scriptName]   SOLUTION       : $SOLUTION"
} else {
	Write-Host "[$scriptName]   solutionName not defined!"
	exit 7762 
}

$workspace = $(Get-Location)
Write-Host "[$scriptName]   pwd            : $workspace"
Write-Host "[$scriptName]   hostname       : $(hostname)" 
Write-Host "[$scriptName]   whoami         : $(whoami)`n"

executeExpression "$AUTOMATIONROOT\processor\buildPackage.ps1 '$BUILDNUMBER' '$BRANCH' '$ACTION' -AUTOMATIONROOT '$AUTOMATIONROOT'"

if ( $defaultBranch ) {
	$defaultBranch = Invoke-Expression "Write-Output $defaultBranch"
} else {
	$defaultBranch = 'master'
}

if ( $BRANCH -eq $defaultBranch ) {
	Write-Host "[$scriptName] Only perform container test in CI for branches, $defaultBranch execution in CD pipeline"
} else {
	Write-Host "[$scriptName] Only perform container test in CI for feature branches, CD for branch $BRANCH"
	if ( $artifactPrefix ) {
		executeExpression ".\release.ps1 $environment"
	} else {
		executeExpression ".\TasksLocal\delivery.ps1 $environment"
	}
}

if ( $skipBranchCleanup ) {
	Write-Host "[$scriptName] Branch not passed and using `$CDAF_BRANCH_NAME override, skipping clean-up ..."
} else {
	if (!( $gitRemoteURL )) {
		Write-Host "[$scriptName] gitRemoteURL not defined in $SOLUTIONROOT/CDAF.solution, skipping clean-up ..."
	} else {
		if ( $gitRemoteURL.contains('$')) {
			$gitRemoteURL = Invoke-Expression "Write-Output ${gitRemoteURL}"
		}

		if (!( $gitRemoteURL )) {
			Write-Host "[$scriptName] gitRemoteURL defined in $SOLUTIONROOT/CDAF.solution but not unresolved, skipping clean-up ..."
		} else {

			Write-Host "[$scriptName] gitRemoteURL = ${gitRemoteURL}, perform branch cleanup ..."
			if (!( $gitUserNameEnvVar )) {
				Write-Host "[$scriptName]   gitRemoteURL defined, but gitUserNameEnvVar not defined, relying on current workspace being up to date"
			} else {
				$userName = Invoke-Expression "Write-Output ${gitUserNameEnvVar}"
				if (!( $userName )) {
					Write-Host "[$scriptName]   $gitUserNameEnvVar contains no value, relying on current workspace being up to date"
				} else {
					$userName = $userName.replace("@","%40")
					if (!( $gitUserPassEnvVar )) { Write-Error "[$scriptName]   gitUserNameEnvVar defined, but gitUserPassEnvVar not defined in $SOLUTIONROOT/CDAF.solution!"; exit 6921 }
					Write-Host "[$scriptName][DEBUG]   `$gitUserPassEnvVar = $gitUserPassEnvVar"
					$userPass = Invoke-Expression "Write-Output ${gitUserPassEnvVar}"
					if (!( $userPass )) {
						Write-Host "[$scriptName]   $gitUserPassEnvVar contains no value, relying on current workspace being up to date"
					} else {
						$urlWithCreds = "https://${userName}:${userPass}@$($gitRemoteURL.Replace('https://', ''))"
						Write-Host "[$scriptName][DEBUG]   `$userPass = $(mask $userPass) (MD5MASK)"
					}
				}
			}

			$isGit = $(git log -n 1 --pretty=%d HEAD 2>$null)
			if ( $LASTEXITCODE -eq 0 ) { 
				$headAttached = $isGit | Select-String '->'
			}

			if (!( $headAttached )) {
				if (!( $userName )) {
					Write-Host "[$scriptName] Workspace is not a Git repository or has detached head, but git credentials not set, skipping branch clean-up ...`n"
					$skipRemoteBranchCheck = 'yes'
				} else {
					Write-Host "[$scriptName] Workspace is not a Git repository or has detached head, work with cache clone ...`n"
					if ( $env:USERPROFILE ) {
						$cacheDir = "$env:USERPROFILE\.cdaf-cache"
					} else {
						$cacheDir = "$env:TEMP\.cdaf-cache"
					}
					$gitRemoteURL = $gitRemoteURL.Trim('/') # remove trailing /                                          # remove trailing /
					$tempParent = (Split-Path -Path $gitRemoteURL -Parent).Replace('https:\', $cacheDir) # retain parent directory for create if required
					$repoName = $gitRemoteURL.Split('/')[-1].Split('.')[0]                               # retrieve basename and remove extension
					$cacheDir = $tempParent + '\' + $repoName                                            # ensure cache directory is unique by using URI

					if ( Test-Path $cacheDir ) {
						executeExpression "cd $cacheDir"
					} else {
						if (!( Test-Path $tempParent )) {
							executeExpression "mkdir -p $tempParent"
						}
						executeExpression "cd $tempParent"
						executeExpression "git clone '${urlWithCreds}'"
						executeExpression "cd $repoName"
						$gitName = $(git config --list | Select-String 'user.name=')
						if (!( $gitName )) {
							git config user.name "Your Name"
						}
						$gitEmail = $(git config --list | Select-String 'user.email=')
						if (!( $gitEmail )) {
							git config user.email "you@example.com"
						}
					}
					executeExpression "git fetch --prune '${urlWithCreds}'"
					$usingCache = $(git log -n 1 --pretty=%d HEAD 2>$null)
					if ( $LASTEXITCODE -ne 0 ) { Write-Error "[$scriptName] Git cache update failed!"; exit 6924 }			
					Write-Host "[$scriptName] Load Remote branches using cache (git ls-remote --heads origin)`n"
					$lsRemote = $(git ls-remote --heads origin)
				}

			} else {

				Write-Host "$headAttached"
				Write-Host "[$scriptName] Refresh Remote branches`n"
				if (!($userName)) {
					executeExpression "git fetch --prune"
					Write-Host "[$scriptName] Load Remote branches (git ls-remote --heads origin)`n"
					$lsRemote = $(git ls-remote --heads origin)
				} else {
					executeExpression "git fetch --prune '${urlWithCreds}'"
					Write-Host "[$scriptName] Load Remote branches (git ls-remote --heads ${urlWithCreds})`n"
					$lsRemote = $(git ls-remote --heads "${urlWithCreds}")
				}

			}

			if (!( $skipRemoteBranchCheck )) {
				$remoteArray = @()
				foreach ( $remoteBranch in $lsRemote ) {
					if ( $remoteBranch.Contains('/')) {
						$remoteArray += $remoteBranch.Split('/')[-1]
					}
				}
				if (!( $remoteArray )) { Write-Error "[$scriptName] git ls-remote --heads origin provided no branches!"; exit 6925 }
				foreach ($remoteBranch in $remoteArray) { # verify array contents
					Write-Host "  $remoteBranch"
				}

				if ( $usingCache ) { # cache only required to build remoteArray
					executeExpression "cd $workspace"
				}

				if ( $headAttached ) {
					Write-Host "`n[$scriptName] Process Local branches (git branch --format='%(refname:short)')`n"
					foreach ( $localBranch in $(git branch --format='%(refname:short)') ) {
						if ( $remoteArray.Contains($localBranch) ) {
							Write-Host "  keep branch ${localBranch}"
						} else {
							executeSuppress "  git branch -D '${localBranch}'"
						}
					}
				}

				if (!( $gitCustomCleanup )) {
					Write-Host "`n[$scriptName] gitCustomCleanup not defined in $SOLUTIONROOT/CDAF.solution, skipping ..."
				} else {
					Write-Host
					executeExpression "$gitCustomCleanup $SOLUTION `$remoteArray"
				}
			}
		}
	}
}

if ( $purgeFeatureBranch ) {
	if ( ! (( $branch -eq $defaultBranch ) -or ( $branch -eq "refs/heads/$defaultBranch" ))) {
		Write-Host "`n[$scriptName] Purge artifacts for feature branches"
		if ( Test-Path './release.ps1' ) {
			executeExpression "Remove-Item -Force ./release.ps1"
			executeExpression "Add-Content ./release.ps1 `"Write-Host 'Dummy artifact created by entry.ps1 for feature branch $branch'`""
		} else {
			$zipPackage = (Get-Item '*.zip').Name
			if ( $zipPackage ) {
				executeExpression "Remove-Item -Force $zipPackage"
				executeExpression "New-Item -Name $zipPackage -ItemType File"
			}
		
			$dirPackage = (Get-Item 'TasksLocal').Name
			if ( $dirPackage ) {
				executeExpression "Remove-Item -Recurse -Force $dirPackage"
				executeExpression "New-Item -Name $dirPackage -ItemType Directory"
				executeExpression "Add-Content ${dirPackage}\readme.md 'Dummy artifact created by entry.ps1 for feature branch $branch'"
			}
		}
	}
}

Write-Host "`n[$scriptName] ----------------------------------"
Write-Host "[$scriptName]   PowerShell Execution Complete"
if (!( $env:CDAF_COMMAND_SHELL )) {
	Write-Host "`n[$scriptName] ----------------------------------"
}
exit 0