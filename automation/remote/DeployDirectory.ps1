Param (
	[string]$sourceDirectory,
	[string]$targetDirectory,
	[string]$filter,
	[string]$replace,
	[string]$showContent,
	[string]$deleteOrphans
)
$scriptName = 'DeployDirectory.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

function isText ($filePath) {
	try {
		$bytes = [System.IO.File]::ReadAllBytes($filePath)
	} catch { return $false }
	if ( $bytes.Length -eq 0 ) { return $true }
	$sample = [math]::Min($bytes.Length, 8000)
	for ( $i = 0; $i -lt $sample; $i++ ) {
		if ( $bytes[$i] -eq 0 ) { return $false }
	}
	return $true
}

# Align two sets of lines using a longest common subsequence, emitting paired rows
function alignLines ($targetLines, $sourceLines) {
	$n = $targetLines.Count
	$m = $sourceLines.Count
	$lcs = New-Object 'int[,]' ($n + 1), ($m + 1)
	for ( $i = $n - 1; $i -ge 0; $i-- ) {
		$nextI = $i + 1
		for ( $j = $m - 1; $j -ge 0; $j-- ) {
			$nextJ = $j + 1
			if ( $targetLines[$i] -ceq $sourceLines[$j] ) {
				$lcs[$i, $j] = $lcs[$nextI, $nextJ] + 1
			} else {
				$skipTarget = $lcs[$nextI, $j]
				$skipSource = $lcs[$i, $nextJ]
				if ( $skipTarget -ge $skipSource ) { $lcs[$i, $j] = $skipTarget } else { $lcs[$i, $j] = $skipSource }
			}
		}
	}

	$rows = @()
	$i = 0; $j = 0
	while (( $i -lt $n ) -or ( $j -lt $m )) {
		if (( $i -lt $n ) -and ( $j -lt $m ) -and ( $targetLines[$i] -ceq $sourceLines[$j] )) {
			$rows += [PSCustomObject]@{ TargetNumber = $i + 1; Target = $targetLines[$i]; SourceNumber = $j + 1; Source = $sourceLines[$j]; Changed = $false }
			$i ++; $j ++
			continue
		}

		if ( $i -eq $n ) {
			$takeSource = $true
		} elseif ( $j -eq $m ) {
			$takeSource = $false
		} else {
			$nextJ = $j + 1
			$nextI = $i + 1
			$skipSource = $lcs[$i, $nextJ]
			$skipTarget = $lcs[$nextI, $j]
			$takeSource = ( $skipSource -ge $skipTarget )
		}

		if ( $takeSource ) {
			$rows += [PSCustomObject]@{ TargetNumber = $null; Target = $null; SourceNumber = $j + 1; Source = $sourceLines[$j]; Changed = $true }
			$j ++
		} else {
			$rows += [PSCustomObject]@{ TargetNumber = $i + 1; Target = $targetLines[$i]; SourceNumber = $null; Source = $null; Changed = $true }
			$i ++
		}
	}
	return $rows
}

function formatColumn ($number, $text, $width) {
	if ( $null -eq $number ) { return ''.PadRight($width) }
	$column = "$($number.ToString().PadLeft(4)): " + ($text -replace "`t", '    ')
	if ( $column.Length -gt $width ) { $column = $column.Substring(0, $width - 3) + '...' }
	return $column.PadRight($width)
}

# Within a block of consecutive changes, pair source and target lines so each row reads as one edit
function emitBlock ($sourceRows, $targetRows, $width) {
	$rowCount = [math]::Max($sourceRows.Count, $targetRows.Count)
	for ( $k = 0; $k -lt $rowCount; $k++ ) {
		if ( $k -lt $sourceRows.Count ) { $left = formatColumn $sourceRows[$k].SourceNumber $sourceRows[$k].Source $width } else { $left = ''.PadRight($width) }
		if ( $k -lt $targetRows.Count ) { $right = formatColumn $targetRows[$k].TargetNumber $targetRows[$k].Target $width } else { $right = '' }
		Write-Host "  $left | $right" -ForegroundColor Yellow
	}
}

# Print the differing lines of two text files in two columns
function sideBySide ($sourceFile, $targetFile) {
	if ( -not ( isText $sourceFile ) -or ( $targetFile -and -not ( isText $targetFile ))) {
		Write-Host "  (binary content, side-by-side listing not applicable)"
		return
	}

	$sourceLines = @(Get-Content -LiteralPath $sourceFile)
	if ( $targetFile ) {
		$targetLines = @(Get-Content -LiteralPath $targetFile)
	} else {
		$targetLines = @()
	}

	try {
		$width = [math]::Max(40, [int](($Host.UI.RawUI.WindowSize.Width - 8) / 2))
	} catch {
		$width = 55
	}

	Write-Host "  $('SOURCE (candidate)'.PadRight($width)) | TARGET (current)"
	Write-Host "  $('-' * $width)-+-$('-' * $width)"

	$sourceRows = @()
	$targetRows = @()
	foreach ( $row in ( alignLines $targetLines $sourceLines )) {
		if ( $row.Changed ) {
			if ( $null -eq $row.SourceNumber ) { $targetRows += $row } else { $sourceRows += $row }
			continue
		}
		emitBlock $sourceRows $targetRows $width
		$sourceRows = @(); $targetRows = @()
	}
	emitBlock $sourceRows $targetRows $width
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ( $sourceDirectory ) {
	Write-Host "[$scriptName]   sourceDirectory : $sourceDirectory"
} else {
	Write-Host "[$scriptName] sourceDirectory not supplied, exiting with `$LASTEXITCODE = 101"; exit 101
}

if ( $targetDirectory ) {
	Write-Host "[$scriptName]   targetDirectory : $targetDirectory"
} else {
	Write-Host "[$scriptName] targetDirectory not supplied, exiting with `$LASTEXITCODE = 102"; exit 102
}

if ( $filter ) {
	Write-Host "[$scriptName]   filter          : $filter"
} else {
	$filter = '*'
	Write-Host "[$scriptName]   filter          : $filter (not supplied, set to default)"
}

if ( $replace -eq 'yes' ) {
	Write-Host "[$scriptName]   replace         : $replace (differing and missing target files will be overwritten)"
} else {
	Write-Host "[$scriptName]   replace         : $replace (compare only, pass yes to update the target)"
}

if ( $showContent -eq 'no' ) {
	Write-Host "[$scriptName]   showContent     : $showContent"
} else {
	$showContent = 'yes'
	Write-Host "[$scriptName]   showContent     : $showContent (pass no to suppress side-by-side listing)"
}

if ( $deleteOrphans -eq 'yes' ) {
	Write-Host "[$scriptName]   deleteOrphans   : $deleteOrphans (target files not in source will be deleted when replace is yes)"
} else {
	Write-Host "[$scriptName]   deleteOrphans   : $deleteOrphans (target files not in source are left unchanged)"
}

if ( ! ( Test-Path -LiteralPath $sourceDirectory )) {
	Write-Host "[$scriptName] Source ($sourceDirectory) not found, exiting with `$LASTEXITCODE = 103"; exit 103
}

if ( ! ( Test-Path -LiteralPath $targetDirectory )) {
	Write-Host "[$scriptName] Target ($targetDirectory) not found, exiting with `$LASTEXITCODE = 104"; exit 104
}

$sourceItem = Get-Item -LiteralPath $sourceDirectory
$targetItem = Get-Item -LiteralPath $targetDirectory

# Both directory and single file arguments are reduced to a list of source/target pairs
$pairs = @()
$orphaned = @()
if ( $sourceItem.PSIsContainer ) {

	if ( ! $targetItem.PSIsContainer ) {
		Write-Host "[$scriptName] Source ($sourceDirectory) is a directory but target ($targetDirectory) is a file, exiting with `$LASTEXITCODE = 105"; exit 105
	}

	$sourceRoot = $sourceItem.FullName
	$targetRoot = $targetItem.FullName

	foreach ( $file in Get-ChildItem -LiteralPath $sourceRoot -Filter $filter -Recurse -File ) {
		$relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\')
		$pairs += [PSCustomObject]@{ Label = $relative; Source = $file.FullName; Target = (Join-Path $targetRoot $relative) }
	}

	foreach ( $file in Get-ChildItem -LiteralPath $targetRoot -Filter $filter -Recurse -File ) {
		$relative = $file.FullName.Substring($targetRoot.Length).TrimStart('\')
		if ( ! ( Test-Path -LiteralPath (Join-Path $sourceRoot $relative) )) {
			$orphaned += [PSCustomObject]@{ Label = $relative; Target = $file.FullName }
		}
	}

} else {

	if ( $targetItem.PSIsContainer ) {
		$targetFile = Join-Path $targetItem.FullName $sourceItem.Name
		$label = $sourceItem.Name
	} else {
		$targetFile = $targetItem.FullName
		if ( $targetItem.Name -eq $sourceItem.Name ) { $label = $sourceItem.Name } else { $label = "$($sourceItem.Name) --> $($targetItem.Name)" }
	}
	$pairs += [PSCustomObject]@{ Label = $label; Source = $sourceItem.FullName; Target = $targetFile }
}

$differing = @()
$missing = @()
$identical = 0

foreach ( $pair in $pairs ) {

	if ( ! ( Test-Path -LiteralPath $pair.Target )) {
		$missing += $pair
		continue
	}

	$sourceHash = (Get-FileHash -LiteralPath $pair.Source -Algorithm SHA256).Hash
	$targetHash = (Get-FileHash -LiteralPath $pair.Target -Algorithm SHA256).Hash
	if ( $sourceHash -eq $targetHash ) {
		$identical ++
	} else {
		$differing += $pair
	}
}

Write-Host "`n[$scriptName] Identical : $identical"
Write-Host "[$scriptName] Different : $($differing.Count)"
Write-Host "[$scriptName] Missing   : $($missing.Count) (in source, not in target)"
Write-Host "[$scriptName] Orphaned  : $($orphaned.Count) (in target, not in source)"

if ( $differing ) {
	Write-Host "`n[$scriptName] --- Differing files ---"
	foreach ( $pair in $differing ) {
		Write-Host "`n[$scriptName] $($pair.Label)"
		if ( $showContent -eq 'yes' ) {
			sideBySide $pair.Source $pair.Target
		}
	}
}

if ( $missing ) {
	Write-Host "`n[$scriptName] --- Files missing from target ---"
	foreach ( $pair in $missing ) {
		Write-Host "[$scriptName] $($pair.Label)"
	}
}

if ( $orphaned ) {
	Write-Host "`n[$scriptName] --- Files only in target ---"
	foreach ( $pair in $orphaned ) {
		Write-Host "[$scriptName] $($pair.Label)"
	}
}

if ( $replace -eq 'yes' ) {
	Write-Host "`n[$scriptName] --- Replacing target files ---"
	foreach ( $pair in ( $differing + $missing )) {
		$parent = Split-Path $pair.Target -Parent
		if ( ! ( Test-Path -LiteralPath $parent )) {
			executeExpression "New-Item -ItemType Directory -Path '$parent' | Out-Null"
		}
		executeExpression "Copy-Item -LiteralPath '$($pair.Source)' -Destination '$($pair.Target)' -Force"
	}

	if ( $orphaned ) {
		if ( $deleteOrphans -eq 'yes' ) {
			Write-Host "`n[$scriptName] --- Deleting orphaned target files ---"
			foreach ( $pair in $orphaned ) {
				executeExpression "Remove-Item -LiteralPath '$($pair.Target)' -Force"
			}
		} else {
			Write-Host "`n[$scriptName] $($orphaned.Count) orphaned target file(s) retained, pass deleteOrphans as yes to remove"
		}
	}
}

Write-Host "`n[$scriptName] --- end ---"
$error.clear()
exit 0
