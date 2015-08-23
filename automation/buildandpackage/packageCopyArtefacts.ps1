function taskFailure ($taskName) {
    write-host
    write-host "[$scriptName] Failure excuting $taskName :" -ForegroundColor Red
    write-host "     Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "     Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    write-host "     Throwing exception : $scriptName HALT" -ForegroundColor Red
	write-host
    throw "$scriptName HALT"
}

# Copy the item, if recursive, treat from as a direcotry and process the contents. If flat, then copy the contents to the root of the working directory
function copyOpt ($manifestFile, $from, $recurse, $flat) {

	if ($recurse) {
	
		foreach ($filename in (Get-ChildItem -Path "$from" -Recurse -Name )) {
			if ($flat) {
				Write-Host "[$scriptName]   $from\$filename --> $WORK_DIR_DEFAULT" 
				New-Item -ItemType File -Path $WORK_DIR_DEFAULT\$filename -Force > $null
				Copy-Item $from\$filename $WORK_DIR_DEFAULT -Force
			} else {
				Write-Host "[$scriptName]   $from\$filename --> $WORK_DIR_DEFAULT\$from" 
				New-Item -ItemType File -Path $WORK_DIR_DEFAULT\$from\$filename -Force > $null
				Copy-Item $from\$filename $WORK_DIR_DEFAULT\$from -Force
			}

			if(!$?){ taskFailure ("Copy-Item $from\$filename $WORK_DIR_DEFAULT\$from -Force") }

			if (-not (Test-Path $WORK_DIR_DEFAULT\$from\$filename -pathType container)) {
				Set-ItemProperty $WORK_DIR_DEFAULT\$from\$filename -name IsReadOnly -value $false
				if(!$?){ taskFailure ("Set-ItemProperty $itemPath -name IsReadOnly -value $false") }
			}
			Add-Content $manifestFile "$WORK_DIR_DEFAULT\$from\$filename"

		}
	
	} else {
	
		Write-Host "[$scriptName]   $from --> $WORK_DIR_DEFAULT" 
		Copy-Item $from $WORK_DIR_DEFAULT
		if(!$?){ taskFailure ("Copy-Item $from $WORK_DIR_DEFAULT") }
		Add-Content $manifestFile "$WORK_DIR_DEFAULT\$from"
	}
	
}

$DRIVER = $args[0]
$WORK_DIR_DEFAULT = $args[1]

$scriptName = $MyInvocation.MyCommand.Name
$manifestFile = getFilename $DRIVER
$manifestFile += "_manifest.txt"

Write-Host
Write-Host "[$scriptName] Copy Artefacts defined in $DRIVER to $WORK_DIR_DEFAULT"

Foreach ($ARTIFACT in get-content $DRIVER) {

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
	Write-Host
	Write-Host "[$scriptName] Artifact list file exists ($DRIVER), but has no contents, copying framework scripts only." -ForegroundColor Yellow
}
