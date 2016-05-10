$scriptName = 'addUserToLocalGroup.ps1'
Write-Host
Write-Host "[$scriptName] Add a user to the local group"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$group = $args[0]
if ($group) {
    Write-Host "[$scriptName] group    : $group"
} else {
	$group = 'Remote Management Users'
    Write-Host "[$scriptName] group    : $group (default)"
}

$userName = $args[1]
if ($userName) {
    Write-Host "[$scriptName] userName : $userName"
} else {
	$userName = 'Deployer'
    Write-Host "[$scriptName] userName : $userName (default)"
}

$domain = $args[2]
if ($domain) {
    Write-Host "[$scriptName] domain   : $domain"
} else {
	$domain = 'SKY'
    Write-Host "[$scriptName] domain   : $domain (default)"
}

Write-Host
Write-Host "[$scriptName] Add $domain/$userName to local group $group."
$de = [ADSI]"WinNT://$env:computername/$group,group"
$de.psbase.Invoke("Add",([ADSI]"WinNT://$domain/$userName").path)

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
