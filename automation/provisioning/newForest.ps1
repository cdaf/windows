function executeExpression ($expression) {
	Write-Host "[$scriptName]   $expression"
	# Execute expression and trap powershell exceptions
	try {
	    Invoke-Expression $expression
	    if(!$?) {
			Write-Host; Write-Host "[$scriptName] Expression failed without an exception thrown. Exit with code 1."; Write-Host 
			exit 1
		}
	} catch {
		Write-Host; Write-Host "[$scriptName] Expression threw exception. Exit with code 2, exception message follows ..."; Write-Host 
		Write-Host "[$scriptName] $_"; Write-Host 
		exit 2
	}
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
	$source = '-Source ' + $media
} else {
	$defaultSource = 'C:\vagrant\.provision\sxs'
	if ( Test-Path $defaultSource ) {
		Write-Host "[$scriptName] Default media path found, using $defaultSource"
		$source = '-Source ' + $defaultSource
	} else {
	    Write-Host "[$scriptName] media not supplied, will attempt to download from windows update."
	}
}

Write-Host
Write-Host "[$scriptName] Install Active Directory Domain Roles and Services"
executeExpression "Install-WindowsFeature -Name `'AD-Domain-Services`' $source"

Write-Host
Write-Host "[$scriptName] Create the new Forest and convert this host into the FSMO Domain Controller"
$securePassword = ConvertTo-SecureString $password -asplaintext -force
executeExpression "Install-ADDSForest -DomainName $forest -SafeModeAdministratorPassword `$securePassword -Force"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
