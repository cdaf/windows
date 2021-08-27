Param (
	[string]$SOLUTION,
	[string[]]$passedArray
)

cmd /c "exit 0"
$Error.Clear()
$scriptName = 'clean.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression "$expression 2> `$null"
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1211 }
	} catch {
		Write-Host "[$scriptName][EXCEPTION] List exception and error array (if populated) and exit with LASTEXITCODE 1212" -ForegroundColor Red
		Write-Host $_.Exception|format-list -force
		if ( $error ) { Write-Host "[$scriptName][ERROR] `$Error = $Error" ; $Error.clear() }
		exit 1212
	}
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red
			if ( $error ) { Write-Host "[$scriptName][ERROR] `$Error = $Error" ; $Error.clear() }
			exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE error follows...`n" -ForegroundColor Yellow
				Write-Host "[$scriptName][WARN] `$Error = $Error" ; $Error.clear()
			}
		} 
	} else {
	    if ( $error ) {
	    	if ( $env:CDAF_IGNORE_WARNING -eq 'no' ) {
				Write-Host "[$scriptName][ERROR] `$Error = $error"; $Error.clear()
				Write-Host "[$scriptName][ERROR] `$env:CDAF_IGNORE_WARNING is 'no' so exiting with LASTEXITCODE 1213 ..."; exit 1213
	    	} else {
		    	Write-Host "[$scriptName][WARN] `$Error = $error" ; $Error.clear()
	    	}
		}
	}
}

Write-Host "`n[$scriptName] --- start ---"
if ($SOLUTION) {
    Write-Host "[$scriptName]   SOLUTION      : $SOLUTION"
} else {
    Write-Host "[$scriptName] SOLUTION not passed!"; exit 1394
}

if ($passedArray) {
	$aphaNumArray = @()
	foreach ($remoteBranch in $passedArray) { # verify array contents
		$i++
		Write-Host "[$scriptName]   remoteBranch${i} : $remoteBranch"
		if ( $remoteBranch -match '/' ) {
			$remoteBranch = $remoteBranch.Split('/')[-1]
		}
		$aphaNumArray += ($remoteBranch -replace '[^a-zA-Z0-9]', '').ToLower()
	}
} else {
    Write-Host "[$scriptName] passedArray not passed!"; exit 1395
}

Write-Host "`n[$scriptName] docker images `"${SOLUTION}*`" --format `"{{.Repository}}:{{.ID}}`"`n"
foreach ( $image in $(docker images "${SOLUTION}*" --format "{{.Repository}}:{{.ID}}" 2>$null )) {
	$imageBranch,$id = $image.Split(':')
	if ( $imageBranch ) {
		$imageCompare = ($imageBranch.Substring($imageBranch.IndexOf('_')+1 , $imageBranch.Length - ($imageBranch.Length - $imageBranch.LastIndexOf('_')) - $imageBranch.IndexOf('_') -1)).ToLower()
		if ( $aphaNumArray.Contains($imageCompare) ) {
			Write-Host "  keep $imageBranch"
		} else {
			Write-Host "  docker rmi -f ${imageBranch}"
			docker rmi ${id}
		}
	}
}

cmd /c "exit 0"
$Error.Clear()
Write-Host "`n[$scriptName] --- end ---"
