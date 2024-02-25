
# Copy the item, if recursive, treat from as a directory and process the contents.
# If flat, then copy the contents to the root of the working directory
function copyOpt ($manifestFile, $from, $first, $second) {

    $arrRecurse = "-recurse", "-r", "--recursive"

	if ($first) {
		if ($arrRecurse -contains $first.ToLower()) { $recurse = '-Recurse' }
		if ($first -ieq '-flat') {	$flat = '-Flat' }
	} else {
		$recurse = '-Recurse'
	}

	if ($second) {
		if ($arrRecurse -contains $second.ToLower()) { $recurse = '-Recurse' }
		if ($second -ieq '-flat') { $flat = '-Flat' }
	}

	try {
		$nodes = Invoke-Expression "Get-ChildItem -Path `"$from`" $recurse -ErrorAction SilentlyContinue"
	    if(!$?) { ERRMSG "[TRAP] `$? = $?" 8821 }
	} catch {
		$message = $_.Exception.Message
		$_.Exception | format-list -force
		$_.Exception.StackTrace
		if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
			ERRMSG "[EXEC][EXCEPTION] $message" $LASTEXITCODE
		} else {
			ERRMSG "[EXEC][EXCEPTION] $message" 8822
		}
	}
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
					if(!$?){ ERRMSG "Copy-Item $sourceRelative $flatTarget -Force" 8824 }
					Set-ItemProperty $flatTarget -name IsReadOnly -value $false
					if(!$?){ ERRMSG "Set-ItemProperty $flatTarget -name IsReadOnly -value $false" 8825 }
				} else {
					Write-Host "[$scriptName]   $sourceRelative --> $WORK_DIR_DEFAULT\$sourceRelative"
					New-Item -ItemType File -Path $WORK_DIR_DEFAULT\$sourceRelative -Force > $null # Creates file and directory path
					Copy-Item $sourceRelative $WORK_DIR_DEFAULT\$sourceRelative -Force
					if(!$?){ ERRMSG "Copy-Item $sourceRelative $WORK_DIR_DEFAULT\$sourceRelative -Force" 8826 }
					Set-ItemProperty $WORK_DIR_DEFAULT\$sourceRelative -name IsReadOnly -value $false
					if(!$?){ ERRMSG "Set-ItemProperty $itemPath -name IsReadOnly -value $false" 8827 }
				}
				Add-Content $manifestFile "$WORK_DIR_DEFAULT\$sourceRelative"
			}
		}
	} else {
		Write-Host "[$scriptName][WARNING] No items found for pattern $from $recurse" -ForegroundColor Yellow
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
