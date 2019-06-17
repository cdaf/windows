Param (
	[string]$remoteURL
)

cmd /c "exit 0"
$scriptName = $MyInvocation.MyCommand.Name

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
    $error.clear()
    Write-Host "$expression"
    try {
        $result = Invoke-Expression $expression
        if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
    } catch { Write-Output $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $result
}
# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeSuppress ($expression) {
    Write-Host "$expression"
    try {
        Invoke-Expression $expression
        if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
    } catch { Write-Host $_.Exception|format-list -force; exit 2 }
    $error.clear()
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] Suppress `$LASTEXITCODE ($LASTEXITCODE)"; cmd /c "exit 0" } # reset LASTEXITCODE
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($remoteURL) {
    Write-Host "[$scriptName] remoteURL    : $remoteURL"
} else {
    Write-Host "[$scriptName] remoteURL    : (not set, use default)"
}
Write-Host "[$scriptName] pwd          : $(pwd)"
Write-Host "[$scriptName] hostname     : $(hostname)" 
Write-Host "[$scriptName] whoami       : $(whoami)" 

$AUTOMATIONROOT = (Get-Item $MyInvocation.MyCommand.Definition).Directory.Parent.FullName
foreach ($item in (Get-ChildItem -Path ".")) {
	if (Test-Path $item -PathType "Container") {
		if (Test-Path "$item\CDAF.solution") {
			$solutionRoot=$item
		}
	}
}
$automationHelper = "$AUTOMATIONROOT\remote"
& $automationHelper\Transform.ps1 "$SOLUTIONROOT\CDAF.solution" | ForEach-Object { invoke-expression $_ }

if (!( ${solutionName} )) {
	Write-Host "`n[$scriptName]   solutionName not defined!"
	exit 7762 
}

Write-Host "`n[$scriptName] Load Local branches`n"
$gitBranch = executeExpression 'git branch'

Write-Host "`n[$scriptName] Local branches`n"
$localBranches = @()
foreach ($branchName in $gitBranch) {
	$branchName = ($branchName.Replace(" ","")).Replace("*","")
	Write-Host "[$scriptName]   $branchName"
	$localBranches += $branchName
}

Write-Host "`n[$scriptName] Load remote branches`n"
executeExpression 'git fetch --prune'
if ($remoteURL) {
	$gitlsremoteheads = executeSuppress "git ls-remote $remoteURL 2>`$null | Select-String 'refs/heads'"
} else {
	$gitlsremoteheads = executeSuppress 'git ls-remote 2>$null | Select-String "refs/heads"'
}

Write-Host "`n[$scriptName] Remote branches`n"
$remoteBranches = @()
foreach ($branchName in $gitlsremoteheads) {
	$branchName = $(($branchName.tostring()).Replace('refs/heads/','|').split('|')[-1])
	Write-Host "[$scriptName]   $branchName"
	$remoteBranches += $branchName
}

Write-Host "`n[$scriptName] Delete Local Branches that are not active on Remote`n"
foreach ( $localBranch in $localBranches ) {
	if ($remoteBranches -contains $localBranch) {
		Write-Host "active branch $localBranch"
	} else {
		executeExpression "git branch -d $localBranch"
	}
}

Write-Host "`n[$scriptName] Load docker images`n"
$dockerImages = executeExpression 'docker images --format "{{.Repository}}:{{.Tag}}:{{.ID}}" 2> $null'

# Numbered lists for summary report
$imagesListBeforeHousekeeping = foreach ($i in $dockerImages) { $i_countb++; echo "$i_countb. $($i.split(':')[0]):$($i.split(':')[1])"`n }

Write-Host "`n[$scriptName] Delete images for inactive branches`n"
$imagesRetained = @()
foreach ($i in $dockerImages) {
    if ($i -like "${solutionName}_*") {
    	$remove = $True
        foreach ($b in $remoteBranches) {
			if (( $i -like "${solutionName}_$b*" ) -or ( $i -like "${solutionName}_container_*" )) {
				$imagesRetained += $( $b_count++; echo "$b_count. $i"`n )
				$remove = $False
                break
			}
		}
        if ( $remove ) {
	        executeSuppress "docker rmi $($i.split(':')[2])"
	        $i_countd++
	        $imagesListDeleted = "$imagesListDeleted $i_countd. $($i.split(':')[0]):$($i.split(':')[1])`n"
        }
    }
}
if (!( $i_countd )) { Write-Host "  < none >" }

Write-Host "`n[$scriptName] Housekeeping Summary`n"
Write-Host "[$scriptName]   List of docker images (before housekeeping)`n $imagesListBeforeHousekeeping"

$images = docker images --format "{{.Repository}}:{{.Tag}}:{{.ID}}" 2> $null
$imagesListPostHousekeeping = foreach ($i in $images) { $i_countp++; echo "$i_countp. $($i.split(':')[0]):$($i.split(':')[1])`n" }
Write-Host "[$scriptName]   List of docker images (after housekeeping)`n $imagesListPostHousekeeping"

Write-Host "[$scriptName]   List of docker images retained`n $imagesRetained"
Write-Host "[$scriptName]   List of docker images deleted`n$imagesListDeleted"

Write-Host "`n[$scriptName] ---------- stop ----------"

