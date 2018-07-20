Param (
  [string]$imagePath,
  [string]$sourcePath
)
$scriptName = 'mountImage.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

# This script is designed for media that is on a file share or web server, it will download the media to the
# local file system tehn mount it.
Write-Host "`n[$scriptName] Usage example"
Write-Host "[$scriptName]   mountImage.ps1 $env:userprofile\image.iso http:\\the.internet\image.iso"
Write-Host "`n[$scriptName] ---------- start ----------"
if ($imagePath) {
    Write-Host "[$scriptName] imagePath  : $imagePath"
} else {
    Write-Host "[$scriptName] imagePath not supplied, supply full path. Exiting!"
    exit 7740
}

if ($sourcePath) {
    Write-Host "[$scriptName] sourcePath : $sourcePath"
	$fallBack = $args[2]
	if ($fallBack) {
	    Write-Host "[$scriptName] fallBack   : $fallBack"
	} else {
		$fallBack = 'c:\.provision'
	    Write-Host "[$scriptName] fallBack   : not supplied defaulting to $fallBack"
	}
} else {
    Write-Host "[$scriptName] sourcePath : not supplied, dismounting $imagePath"
    Write-Host "[$scriptName] fallBack   : (not applicable when sourcePath not passed)"
}

if ($sourcePath) {
	if ($imagePath -eq $sourcePath ) {
		Write-Host "`n[$scriptName] Source and image are the same, do not attempt copy, just mount $imagePath ...`n"
	} else {
		Write-Host "`n[$scriptName] Obtain image and mount...`n"
		if ($sourcePath -like 'http*') {	
		    Write-Host "[$scriptName] Attempt download from web server $sourcePath"
			$filename = $sourcePath.Substring($sourcePath.LastIndexOf("/") + 1)
			if ( Test-Path $imagePath ) {
				Write-Host "[scriptName.ps1] $imagePath exists, download not required"
			} else {
			
				$webclient = new-object system.net.webclient
				Write-Host "[$scriptName] $webclient.DownloadFile($sourcePath, $imagePath)"
				try {
					$webclient.DownloadFile($sourcePath, $imagePath)
				} catch {
					Write-Host "[$scriptName] Download from $sourcePath failed, falling back to $fallBack"
					executeExpression "Copy-Item `"$fallBack`" `"$imagePath`""
				}
			}
		} else {
		    Write-Host "[$scriptName] Attempt copy from file share $sourcePath"
		    if ( Test-Path $sourcePath ) {
				executeExpression "Copy-Item `"$sourcePath`" `"$imagePath`""
			} else {
				$parentPath = Split-Path $sourcePath
			    Write-Host "[$scriptName] $sourcePath is not found, listing parent directory $parentPath"
			    dir $parentPath
			    exit 7741
		    }
		}
	}

    Write-Host "[$scriptName] `$result = Mount-DiskImage -ImagePath `"$imagePath`" -Passthru"
	$result = Mount-DiskImage -ImagePath "$imagePath" -Passthru
	if ($result) {
		$driveLetter = ($result | Get-Volume).DriveLetter
	    Write-Host "`n[$scriptName] Drive Letter : $driveLetter"
		$result = executeExpression "[Environment]::SetEnvironmentVariable(`'MOUNT_DRIVE_LETTER`', `"$driveLetter`:\`", `'User`')"
	} else {
	    Write-Host "`n[$scriptName] Mount failed! Exit with lastexitcode=7742`n";exit 7742
	}

# Dismount image
} else {

    Write-Host
	executeExpression "Dismount-DiskImage -ImagePath `"$imagePath`""
}

Write-Host "`n[$scriptName] ---------- stop ----------`n"
exit 0