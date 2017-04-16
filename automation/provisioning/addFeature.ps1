Param (
  [string]$feature,
  [string]$options,
  [string]$media,
  [string]$wimIndex
)
$scriptName = 'addFeature.ps1'

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

Write-Host "`n[$scriptName] Add Windows Feature using DIM source if provided."
Write-Host "`n[$scriptName] ---------- start ----------"
if ($feature) {
    Write-Host "[$scriptName] feature   : $feature"
} else {
	$feature = 'Web-Scripting-Tools'
    Write-Host "[$scriptName] feature   : $feature (default)"
}

if ($options) {
    Write-Host "[$scriptName] options   : $options"
} else {
    Write-Host "[$scriptName] options   : not supplied"
}

if ($media) {
    Write-Host "[$scriptName] media     : $media"
} else {
	$media = 'c:\.provision\install.wim'
    Write-Host "[$scriptName] media     : $media (default)"
}

if ($wimIndex) {
    Write-Host "[$scriptName] wimIndex  : $wimIndex"
} else {
	$wimIndex = '2'
    Write-Host "[$scriptName] wimIndex  : $wimIndex (default, Standard Edition)"
}
# Provisioning Script builder
if ( $env:PROV_SCRIPT_PATH ) {
	Add-Content "$env:PROV_SCRIPT_PATH" "executeExpression `"./automation/provisioning/$scriptName $feature $options $media $wimIndex `""
}

# If media is not found, install will attempt to download from windows update
if ( Test-Path $media ) {
	if ( $media -match ':' ) {
		$sourceOption = '-Source wim:' + $media + ":$wimIndex"
		Write-Host "[$scriptName] Media path found, using source option $sourceOption"
	} else {
		$sourceOption = '-Source ' + $media
		Write-Host "[$scriptName] Media path found, using source option $sourceOption"
	}
} else {
    Write-Host "[$scriptName] media path not found, will attempt to download from windows update."
}

Write-Host "`n[$scriptName] Install $feature"
executeExpression "Install-WindowsFeature -Name `'$feature`' $options $sourceOption" 

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0
