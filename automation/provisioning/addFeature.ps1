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


$scriptName = 'addFeature.ps1'
Write-Host
Write-Host "[$scriptName] Add Windows Feature using DIM source if provided."
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$feature = $args[0]
if ($feature) {
    Write-Host "[$scriptName] feature   : $feature"
} else {
	$feature = 'Web-Scripting-Tools'
    Write-Host "[$scriptName] feature   : $feature (default)"
}

$options = $args[1]
if ($options) {
    Write-Host "[$scriptName] options   : $options"
} else {
    Write-Host "[$scriptName] options   : not supplied"
}

$media = $args[2]
if ($media) {
    Write-Host "[$scriptName] media     : $media"
} else {
	$media = 'c:\.provision\install.wim'
    Write-Host "[$scriptName] media     : $media (default)"
}

$wimIndex = $args[3]
if ($wimIndex) {
    Write-Host "[$scriptName] wimIndex  : $wimIndex"
} else {
	$wimIndex = '2'
    Write-Host "[$scriptName] wimIndex  : $wimIndex (default, Standard Edition)"
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

Write-Host
Write-Host "[$scriptName] Install $feature"
executeExpression "Install-WindowsFeature -Name `'$feature`' $options $sourceOption" 

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
