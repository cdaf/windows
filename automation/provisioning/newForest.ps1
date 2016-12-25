function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
}

$scriptName = 'newForest.ps1'
Write-Host
Write-Host "[$scriptName] New Forest, Windows Server 2012 and above"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$forest = $args[0]
if ($forest) {
    Write-Host "[$scriptName] forest   : $forest"
} else {
	$forest = 'sky.net'
    Write-Host "[$scriptName] forest   : $forest (default)"
}

$password = $args[1]
if ($password) {
    Write-Host "[$scriptName] password : ********** "
} else {
	$password = 'Puwreyu5Asegucacr6za'
    Write-Host "[$scriptName] password : ********** (default)"
}

$media = $args[2]
if ($media) {
    Write-Host "[$scriptName] media    : $media"
} else {
	$media = 'C:\.provision\install.wim'
    Write-Host "[$scriptName] media    : $media (default)"
}

$wimIndex = $args[3]
if ($wimIndex) {
    Write-Host "[$scriptName] wimIndex : $wimIndex"
} else {
	$wimIndex = '2'
    Write-Host "[$scriptName] wimIndex : $wimIndex (default, Standard Edition)"
}

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
Write-Host "[$scriptName] Install Active Directory Domain Roles and Services"
executeExpression "Install-WindowsFeature -Name `'AD-Domain-Services`' -IncludeAllSubFeature -IncludeManagementTools $sourceOption"
executeExpression "Install-WindowsFeature -Name `'DNS`' -IncludeAllSubFeature -IncludeManagementTools $sourceOption"

Write-Host
Write-Host "[$scriptName] Create the new Forest and convert this host into the FSMO Domain Controller"
$securePassword = ConvertTo-SecureString $password -asplaintext -force
executeExpression "Install-ADDSForest -DomainName $forest -SafeModeAdministratorPassword `$securePassword -Force"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
