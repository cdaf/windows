# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptName = 'installAgent.ps1'

Write-Host
Write-Host "[$scriptName] ---------- start ----------"

$mediaDirectory = $args[0]
if ( $mediaDirectory ) {
	Write-Host "[$scriptName] mediaDirectory : $mediaDirectory"
} else {
	$mediaDirectory = 'C:\.provision'
	Write-Host "[$scriptName] mediaDirectory : $mediaDirectory (default)"
}

$files = Get-ChildItem "$mediaDirectory/vsts-*"
if ($files) {
	Write-Host;	Write-Host "[$scriptName] Files available ..."
	foreach ($file in $files) {
		Write-Host "[$scriptName]   $($file.name)"
		$mediaFileName = $($file.name)
	}
	Write-Host; Write-Host "[$scriptName] Using latest file ($mediaFileName)"
} else {
	Write-Host "[$scriptName] mediaFileName with prefix `'vsts-`' not found, exiting with error code 1"; exit 1
}

Write-Host

# Extract using default instructions from Microsoft
if (Test-Path "C:\agent") {
	executeExpression "Remove-Item `"C:\agent`" -Recurse -Force"
}
executeExpression "mkdir C:\agent"
executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory(`"$mediaDirectory\$mediaFileName`", `"C:\agent`")"

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host
