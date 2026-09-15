Param (
	[string]$sourceDirectory,
	[string]$targetDirectory,
	[string]$filter,
	[string]$replace,
	[string]$showContent
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

if ( ! ( Test-Path -LiteralPath $sourceDirectory )) {
	Write-Host "[$scriptName] Source directory ($sourceDirectory) not found, exiting with `$LASTEXITCODE = 103"; exit 103
}

if ( ! ( Test-Path -LiteralPath $targetDirectory )) {
	Write-Host "[$scriptName] Target directory ($targetDirectory) not found, exiting with `$LASTEXITCODE = 104"; exit 104
}

$sourceRoot = (Resolve-Path -LiteralPath $sourceDirectory).Path
$targetRoot = (Resolve-Path -LiteralPath $targetDirectory).Path

$differing = @()
$missing = @()
$identical = 0

foreach ( $sourceFile in Get-ChildItem -LiteralPath $sourceRoot -Filter $filter -Recurse -File ) {

	$relative = $sourceFile.FullName.Substring($sourceRoot.Length).TrimStart('\')
	$targetFile = Join-Path $targetRoot $relative

	if ( ! ( Test-Path -LiteralPath $targetFile )) {
		$missing += $relative
		continue
	}

	$sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
	$targetHash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash
	if ( $sourceHash -eq $targetHash ) {
		$identical ++
	} else {
		$differing += $relative
	}
}

$orphaned = @()
foreach ( $file in Get-ChildItem -LiteralPath $targetRoot -Filter $filter -Recurse -File ) {
	$relative = $file.FullName.Substring($targetRoot.Length).TrimStart('\')
	if ( ! ( Test-Path -LiteralPath (Join-Path $sourceRoot $relative) )) {
		$orphaned += $relative
	}
}

Write-Host "`n[$scriptName] Identical : $identical"
Write-Host "[$scriptName] Different : $($differing.Count)"
Write-Host "[$scriptName] Missing   : $($missing.Count) (in source, not in target)"
Write-Host "[$scriptName] Orphaned  : $($orphaned.Count) (in target, not in source)"

if ( $differing ) {
	Write-Host "`n[$scriptName] --- Differing files ---"
	foreach ( $relative in $differing ) {
		Write-Host "`n[$scriptName] $relative"
		if ( $showContent -eq 'yes' ) {
			sideBySide (Join-Path $sourceRoot $relative) (Join-Path $targetRoot $relative)
		}
	}
}

if ( $missing ) {
	Write-Host "`n[$scriptName] --- Files missing from target ---"
	foreach ( $relative in $missing ) {
		Write-Host "[$scriptName] $relative"
	}
}

if ( $orphaned ) {
	Write-Host "`n[$scriptName] --- Files only in target ---"
	foreach ( $relative in $orphaned ) {
		Write-Host "[$scriptName] $relative"
	}
}

if ( $replace -eq 'yes' ) {
	Write-Host "`n[$scriptName] --- Replacing target files ---"
	foreach ( $relative in ( $differing + $missing )) {
		$targetFile = Join-Path $targetRoot $relative
		$parent = Split-Path $targetFile -Parent
		if ( ! ( Test-Path -LiteralPath $parent )) {
			executeExpression "New-Item -ItemType Directory -Path '$parent' | Out-Null"
		}
		executeExpression "Copy-Item -LiteralPath '$(Join-Path $sourceRoot $relative)' -Destination '$targetFile' -Force"
	}
}

Write-Host "`n[$scriptName] --- end ---"
$error.clear()
exit 0
