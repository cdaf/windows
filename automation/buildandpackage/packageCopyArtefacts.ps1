# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	try {
		$result = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    return $result
}

function taskFailure ($taskName) {
    write-host "`n[$scriptName] Failure executing :" -ForegroundColor Red
    write-host "[$scriptName] $taskName :`n" -ForegroundColor Red
    throw "$scriptName HALT"
}

# Copy the item, if recursive, treat from as a direcotry and process the contents.
# If flat, then copy the contents to the root of the working directory
function copyOpt ($manifestFile, $from, $first, $second) {

	if ($first) {
		$arrRecurse = "-recurse", "-r", "--recursive"
		if ($arrRecurse -contains $first.ToUpper()) { $recurse = '-Recurse' }
		if ($first.ToUpper() -eq '-flat') {	$flat = '-Flat' }
	} else {
		$recurse = '-Recurse'
	}

	if ($second) {
		$arrRecurse = "-recurse", "-r", "--recursive"
		if ($arrRecurse -contains $second.ToUpper()) { $recurse = '-Recurse' }
		if ($second.ToUpper() -eq '-flat') { $flat = '-Flat' }
	}

	$nodes = executeExpression "Get-ChildItem -Path `"$from`" $recurse"
	if ( $nodes ) {
		foreach ( $node in $nodes ) {
			if  (Test-Path $node.FullName -pathType 'leaf' ) {
				$sourceRelative = $(Resolve-Path -Relative $node.FullName)
				if ( $sourceRelative.StartsWith(".\") ) {
					$sourceRelative = $sourceRelative.Substring(2)
				}
				
				if ( $flat ) {
					$flatTarget = "$WORK_DIR_DEFAULT\$($node.name)"
					Write-Host "[$scriptName]   $sourceRelative --> $flatTarget"
					New-Item -ItemType File -Path $flatTarget -Force > $null 
					Copy-Item $sourceRelative $flatTarget -Force
					if(!$?){ taskFailure ("Copy-Item $sourceRelative $flatTarget -Force") }
					Set-ItemProperty $flatTarget -name IsReadOnly -value $false
					if(!$?){ taskFailure ("Set-ItemProperty $flatTarget -name IsReadOnly -value $false") }
				} else {
					Write-Host "[$scriptName]   $sourceRelative --> $WORK_DIR_DEFAULT\$sourceRelative"
					New-Item -ItemType File -Path $WORK_DIR_DEFAULT\$sourceRelative -Force > $null # Creates file and directory path
					Copy-Item $sourceRelative $WORK_DIR_DEFAULT\$sourceRelative -Force
					if(!$?){ taskFailure ("Copy-Item $sourceRelative $WORK_DIR_DEFAULT\$sourceRelative -Force") }
					Set-ItemProperty $WORK_DIR_DEFAULT\$sourceRelative -name IsReadOnly -value $false
					if(!$?){ taskFailure ("Set-ItemProperty $itemPath -name IsReadOnly -value $false") }
				}
				Add-Content $manifestFile "$WORK_DIR_DEFAULT\$sourceRelative"
			}
		}
	} else {
		Write-Host "[$scriptName]   No items found for pattern $from $recurse"
	}
}

$DRIVER = $args[0]
$WORK_DIR_DEFAULT = $args[1]

$scriptName = $MyInvocation.MyCommand.Name
$manifestFile = getFilename $DRIVER
$manifestFile += "_manifest.txt"

Write-Host "`n[$scriptName] Copy Artefacts defined in $DRIVER to $WORK_DIR_DEFAULT"

foreach ($ARTIFACT in get-content $DRIVER) {

    # Don't process empty line
    if ($ARTIFACT) {
        # discard all characters after comment marker
        $noComment=$ARTIFACT.split("#")
        $noComment=$noComment[0]

        # Do not attempt any processing when a line is just a comment
        if ($noComment) {

			# If the artefact has a space, the second part is treated as the option parameter
			$artefactOpt=$noComment.split(" ")
			copyOpt $manifestFile $artefactOpt[0] $artefactOpt[1]
		}
	}
}

if (-not (Test-Path $manifestFile)) {
	Write-Host "`n[$scriptName] Artifact list file exists ($DRIVER), but has no contents, copying framework scripts only.`n" -ForegroundColor Yellow
}
