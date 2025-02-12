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
$env:CDAF_DEBUG_LOGGING = "[$(Get-Date)] Debug Logging Started`n"

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


# Consolidated Error processing function
#  required : error message
#  optional : exit code, if not supplied only error message is written
function ERRMSG ($message, $exitcode) {
	if ( $exitcode ) {
		if ( $exitcode ) {
			Write-Host "`n[$scriptName]$message" -ForegroundColor Red
		} else {
			Write-Host "`n[$scriptName] ERRMSG triggered without message parameter." -ForegroundColor Red
		}
	} else {
		if ( $exitcode ) {
			Write-Warning "`n[$scriptName]$message"
		} else {
			Write-Warning "`n[$scriptName] ERRMSG triggered without message parameter."
		}
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
		if ( $env:CDAF_ERROR_DIAG ) {
			Write-Host "`n[$scriptName] Invoke custom diag `$env:CDAF_ERROR_DIAG = $env:CDAF_ERROR_DIAG`n"
			try {
				Invoke-Expression $env:CDAF_ERROR_DIAG
			    if(!$?) { Write-Host "[CDAF_ERROR_DIAG] `$? = $?" }
			} catch {
				$message = $_.Exception.Message
				$_.Exception | format-list -force
			}
		    if ( $LASTEXITCODE ) {
		    	if ( $LASTEXITCODE -ne 0 ) {
					Write-Host "[CDAF_ERROR_DIAG][EXIT] `$LASTEXITCODE is $LASTEXITCODE"
				}
			}
		}
		Write-Host "`n[$scriptName] Exit with LASTEXITCODE = $exitcode`n" -ForegroundColor Red
		exit $exitcode
	}
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { ERRMSG "[TRAP] `$? = $?" 1211 }
	} catch {
		$message = $_.Exception.Message
		$_.Exception | format-list -force
		$_.Exception.StackTrace
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
			ERRMSG "[EXEC][EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[EXEC][EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			ERRMSG "[EXEC][EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
		} else {
			if ( $error ) {
				ERRMSG "[EXEC][WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[EXEC][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				ERRMSG "[EXEC][WARN] `$LASTEXITCODE not set, but standard error populated"
	    	}
		}
	}
}

function executeReturn ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		$return = Invoke-Expression $expression
	    if(!$?) { ERRMSG "[RET_TRAP] `$? = $?" 1211 }
	} catch {
		$message = $_.Exception.Message
		$_.Exception | format-list -force
		$_.Exception.StackTrace
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
			ERRMSG "[RET_EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[RET_EXCEPTION] $message" 1212
		}
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			ERRMSG "[RET_EXIT] `$LASTEXITCODE is $LASTEXITCODE" $LASTEXITCODE
		} else {
			if ( $error ) {
				ERRMSG "[RET_WARN] `$LASTEXITCODE is $LASTEXITCODE, but standard error populated"
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				ERRMSG "[RET_ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting" 1213
	    	} else {
				ERRMSG "[RET_WARN] `$LASTEXITCODE not set, but standard error populated"
	    	}
		}
	}
	return $return
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

# 2.5.2 Return SHA256 as uppercase Hexadecimal, default algorith is SHA256, but setting explicitely should this change in the future
function MASKED ($value) {
	(Get-FileHash -InputStream $([IO.MemoryStream]::new([byte[]][char[]]$value)) -Algorithm SHA256).Hash
}

if ( $env:CDAF_COMMAND_SHELL ) {
	$env:CDAF_COMMAND_SHELL = ''
} else {
	Write-Host "`n[$scriptName] ----------------------------------"
}

Write-Host "[$scriptName]     Start PowerShell Execution"
Write-Host "[$scriptName] ----------------------------------"
if ( $BUILDNUMBER ) {
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

if ( $BRANCH ) {
	if ( $BRANCH.contains('$')) {
		$BRANCH = Invoke-Expression "Write-Output $BRANCH"
	}

	$origRev = $BRANCH
	if ( $BRANCH -match '/' ) {
		$BRANCH = $BRANCH.Split('/')[-1]
	}
	$BRANCH = ($BRANCH -replace '[^a-zA-Z0-9]', '').ToLower()
	if ( $origRev -ne $BRANCH ) {
	    Write-Host "[$scriptName]   BRANCH         : $BRANCH (cleansed from $origRev)"
	} else {
	    Write-Host "[$scriptName]   BRANCH         : $BRANCH"
	}

} else {
	if ( $env:CDAF_BRANCH_NAME ) {
		$branch = $env:CDAF_BRANCH_NAME
		$skipBranchCleanup = 'yes'
	    Write-Host "[$scriptName]   BRANCH         : $BRANCH (not supplied, derived from `$env:CDAF_BRANCH_NAME)"
	} else {
		$versionTest = $(cmd /c git --version 2>&1)
		if ( $LASTEXITCODE -ne 0 ) {
			cmd /c "exit 0"
			$BRANCH = 'nogit'
			Write-Host "[$scriptName]   BRANCH         : $BRANCH (Git not installed, this entry point is intended for Git workspaces, set to default)"
		} else {
			$BRANCH = $(git rev-parse --abbrev-ref HEAD 2>&1)
			if ( $LASTEXITCODE -eq 0 ) {

				$origRev = $BRANCH
				if ( $BRANCH -match '/' ) {
					$BRANCH = $BRANCH.Split('/')[-1]
				}
				$BRANCH = ($BRANCH -replace '[^a-zA-Z0-9]', '').ToLower()
				if ( $origRev -ne $BRANCH ) {
				    Write-Host "[$scriptName]   BRANCH         : $BRANCH (determined from workspace, cleansed from $origRev)"
				} else {
					Write-Host "[$scriptName]   BRANCH         : $BRANCH (determined from workspace)"
				}
			} else {
				cmd /c "exit 0"
				$BRANCH = 'notworkspace'
				Write-Host "[$scriptName]   BRANCH         : $BRANCH (not a Git workspace, set to default)"
			}
		}
	}
}

if ( $ACTION ) {
	if ( $ACTION.contains('$')) {
		$ACTION = Invoke-Expression "Write-Output $ACTION"
	}
    Write-Host "[$scriptName]   ACTION         : $ACTION"
} else {
    Write-Host "[$scriptName]   ACTION         : (not passed)"
}

if ( $AUTOMATIONROOT ) {
    Write-Host "[$scriptName]   AUTOMATIONROOT : $AUTOMATIONROOT"
} else {
	$AUTOMATIONROOT = split-path -parent $MyInvocation.MyCommand.Definition
    Write-Host "[$scriptName]   AUTOMATIONROOT : $AUTOMATIONROOT (not supplied, derived from invocation)"
}

# Check for user defined solution folder, i.e. outside of automation root, if found override solution root
Write-Host "[$scriptName]   SOLUTIONROOT   : " -NoNewline
foreach ($item in (Get-ChildItem -Path ".")) {
	if (Test-Path $item -PathType "Container") {
		if (Test-Path "$item\CDAF.solution") {
			$SOLUTIONROOT = $item.FullName
		}
	}
}

if ( $SOLUTIONROOT ) {
	$SOLUTIONROOT = (Get-Item $SOLUTIONROOT).FullName
	write-host "$SOLUTIONROOT (CDAF.solution found)"
} else {
	ERRMSG "[NO_SOLUTION_ROOT] No directory found containing CDAF.solution, please create a single occurrence of this file." 6920
}

$CDAF_CORE = "$AUTOMATIONROOT\remote"
& "$CDAF_CORE\Transform.ps1" "$SOLUTIONROOT\CDAF.solution" | ForEach-Object { invoke-expression "$_" }

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

if ( $defaultBranch ) {
	$defaultBranch = Invoke-Expression "Write-Output $defaultBranch"
	Write-Host "[$scriptName]   defaultBranch  : $defaultBranch"
} else {
	$defaultBranch = 'master'
	Write-Host "[$scriptName]   defaultBranch  : $defaultBranch (not set, default applied)"
}

if ( ${solutionName} ) {
	$SOLUTION = $solutionName
	Write-Host "[$scriptName]   SOLUTION       : $SOLUTION"
} else {
	ERRMSG "[$scriptName]   solutionName not defined!" 6921
}

$WORKSPACE_ROOT = $(Get-Location)
Write-Host "[$scriptName]   WORKSPACE_ROOT : $WORKSPACE_ROOT"
Write-Host "[$scriptName]   hostname       : $(hostname)" 
Write-Host "[$scriptName]   whoami         : $(whoami)"

# Check for customised CI process
Write-Host "[$scriptName]   ciProcess      : " -NoNewline
if ( Test-Path "$SOLUTIONROOT\buildPackage.ps1" ) {
	$ciProcess="$SOLUTIONROOT\buildPackage.ps1"
	write-host "$ciProcess (override)"
} else {
	$ciProcess="$AUTOMATIONROOT\processor\buildPackage.ps1"
	write-host "$ciProcess (default)"
}

executeExpression "& '$ciProcess' '$BUILDNUMBER' '$BRANCH' '$ACTION'"

if ( $BRANCH -eq $defaultBranch ) {
	Write-Host "[$scriptName] Only perform container test in CI for branches, $defaultBranch execution in CD pipeline"
} else {
	if ( Test-Path "$SOLUTIONROOT\feature-branch.properties" ) {
		Write-Host "[$scriptName] Found $SOLUTIONROOT\feature-branch.properties, test for match with '$BRANCH' ...`n"
		try {
			$propList = & $AUTOMATIONROOT\remote\Transform.ps1 "$SOLUTIONROOT\feature-branch.properties"
			foreach ( $featureProp in $propList ) {
				$featurePrefix, $featureEnv = $featureProp -split '=', 2
				$featurePrefix = $featurePrefix.substring(1)                    # trim off the $ prefix applied by Transform.ps1
				$featureEnv = $featureEnv.substring(1)                          # trim off the opening ' applied by Transform.ps1
				$featureEnv = $featureEnv.Substring(0, $featureEnv.Length - 1)  # trim off the closing ' applied by Transform.ps1
				if ( $BRANCH -match ${featurePrefix} ) {
					Write-Host "  Deploy feature branch containing '$featurePrefix'"
					$featureBranchProcess = 'yes'
					if ( $artifactPrefix ) {
						executeExpression ".\release.ps1 $featureEnv"
					} else {
						executeExpression ".\TasksLocal\delivery.ps1 $featureEnv"
					}
				} else {
					Write-Host "  Skip feature branch prefix '$featurePrefix'"
				}
			}
			if(!$?) { ERRMSG "FEATURE_BRANCH_PROPLD_TRAP" 6922 }
		} catch { ERRMSG "FEATURE_BRANCH_PROPLD_EXCEPTION" 6923 }

		if ( ! $featureBranchProcess ) {
			if ( $defaultEnvironment ) {
				Write-Host "[$scriptName] Performing container test in CI for feature branch ($BRANCH), CD for branch $defaultBranch"
				if ( $artifactPrefix ) {
					executeExpression ".\release.ps1 $environment"
				} else {
					executeExpression ".\TasksLocal\delivery.ps1 $environment"
				}
			} else {
				Write-Host "[$scriptName] No feature branches processed and defaultEnvironment not set, feature branch delivery not attempted."
			}
		}	
	} else {
		Write-Host "[$scriptName] $SOLUTIONROOT\feature-branch.properties not found, performing container test in CI for feature branch ($BRANCH), CD for branch $defaultBranch"
		if ( $artifactPrefix ) {
			executeExpression ".\release.ps1 $environment"
		} else {
			executeExpression ".\TasksLocal\delivery.ps1 $environment"
		}
	}
}

if ( $skipBranchCleanup ) {
	Write-Host "[$scriptName] Branch not passed and using `$CDAF_BRANCH_NAME override, skipping clean-up ..."
} else {
	if (!( $gitRemoteURL )) {
		Write-Host "[$scriptName] gitRemoteURL not defined in $SOLUTIONROOT/CDAF.solution, skipping clean-up ..."
	} else {
		$env:CDAF_DEBUG_LOGGING += "[URL_VAR] gitRemoteURL = $gitRemoteURL`n"
		$gitRemoteURL = Invoke-Expression "Write-Output ${gitRemoteURL}"
		$env:CDAF_DEBUG_LOGGING += "[URL_LOADED] gitRemoteURL = $gitRemoteURL`n"

		if (!( $gitRemoteURL )) {
			Write-Host "[$scriptName] gitRemoteURL defined in $SOLUTIONROOT/CDAF.solution but not resolved, skipping clean-up ..."
		} else {

			Write-Host "[$scriptName] gitRemoteURL = ${gitRemoteURL}, perform branch cleanup ..."
			if (!( $gitUserNameEnvVar )) {
				Write-Host "[$scriptName]   gitRemoteURL defined, but gitUserNameEnvVar not defined, relying on current workspace being up to date"
			} else {
				$env:CDAF_DEBUG_LOGGING += "[USERNAME_VAR] gitUserNameEnvVar = $gitUserNameEnvVar`n"
				$userName = Invoke-Expression "Write-Output ${gitUserNameEnvVar}"
				$env:CDAF_DEBUG_LOGGING += "[USERNAME_LOADED] userName = $userName`n"
				if (!( $userName )) {
					Write-Host "[$scriptName]   $gitUserNameEnvVar contains no value, relying on current workspace being up to date"
				} else {
					$userName = $userName.replace("@","%40")
					if (!( $gitUserPassEnvVar )) { ERRMSG "[$scriptName]   gitUserNameEnvVar defined, but gitUserPassEnvVar not defined in $SOLUTIONROOT/CDAF.solution!" 6924 }
					$env:CDAF_DEBUG_LOGGING += "[PASS_VAR] gitUserPassEnvVar = $gitUserPassEnvVar`n"
					$userPass = Invoke-Expression "Write-Output ${gitUserPassEnvVar}"
					$env:CDAF_DEBUG_LOGGING += "[PASS_LOADED] userPass = $userPass`n"
					if (!( $userPass )) {
						Write-Host "[$scriptName]   $gitUserPassEnvVar contains no value, relying on current workspace being up to date"
					} else {
						$env:CDAF_DEBUG_LOGGING += "[PASS_MASK] userPass = $(MASKED $userPass) (MASKED)`n"
						$urlWithCreds = "https://${userName}:${userPass}@$($gitRemoteURL.Replace('https://', ''))"
						$env:CDAF_DEBUG_LOGGING += "[SET_URL] urlWithCreds = $urlWithCreds`n"
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
					$gitRemoteURL = $gitRemoteURL.Trim('/')                                              # remove trailing /
					$env:CDAF_DEBUG_LOGGING += "[DETACHED_HEAD_URL] gitRemoteURL = $gitRemoteURL`n"
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
					$usingCache = executeReturn 'git log -n 1 --pretty=%d HEAD 2>$null'
					if ( $LASTEXITCODE -ne 0 ) { ERRMSG "[$scriptName] Git cache update failed!" 6925 }			
					$lsRemote = executeReturn "git ls-remote --heads '${urlWithCreds}'"
				}

			} else {

				Write-Host "$headAttached"
				Write-Host "[$scriptName] Refresh Remote branches`n"
				if (!($userName)) {
					executeExpression "git fetch --prune"
					$lsRemote = executeReturn "git ls-remote --heads origin"
				} else {
					executeExpression "git fetch --prune '${urlWithCreds}'"
					$lsRemote = executeReturn "git ls-remote --heads '${urlWithCreds}'"
				}

			}

			if (!( $skipRemoteBranchCheck )) {
				$remoteArray = @()
				foreach ( $remoteBranch in $lsRemote ) {
					if ( $remoteBranch.Contains('/')) {
						$remoteArray += $remoteBranch.Split('/')[-1]
					}
				}
				if (!( $remoteArray )) { ERRMSG "[$scriptName] git ls-remote --heads provided no branches!" 6926 }
				if ( $usingCache ) { # cache only required to build remoteArray
					executeExpression "cd $WORKSPACE_ROOT"
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
				} else {
					Write-Host "`n[$scriptName] Detached head, branches not processed:"
					foreach ($remoteBranch in $remoteArray) { # verify array contents
						Write-Host "  $remoteBranch"
					}
				}

				if ( $gitCustomCleanup ) {
					Write-Host "`n[$scriptName] Perform $gitCustomCleanup, comparing for $remoteArray"
					executeExpression "$gitCustomCleanup $SOLUTION `$remoteArray"
				} else {
					Write-Host "`n[$scriptName] gitCustomCleanup not defined in $SOLUTIONROOT/CDAF.solution, skipping ..."
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
	Write-Host "[$scriptName] ----------------------------------"
}
exit 0
