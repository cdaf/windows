$scriptName = 'ADGroupMember.ps1'
Write-Host
Write-Host "[$scriptName] New User on Domain, Windows Server 2012 and above"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$userName = $args[0]
if ($userName) {
    Write-Host "[$scriptName] userName : $userName"
} else {
	$userName = 'Deployer'
    Write-Host "[$scriptName] userName : $userName (default)"
}

$group = $args[1]
if ($group) {
    Write-Host "[$scriptName] group    : $group"
} else {
	$group = 'Remote Desktop Users'
    Write-Host "[$scriptName] group    : $group (default)"
}

Write-Host
Write-Host "[$scriptName]   Add-ADGroupMember $group –Member $userName"
Add-ADGroupMember $group –Member $userName

Write-Host
Write-Host "[$scriptName]   List all members of group $group"
foreach ($member in (Get-ADGroupMember $group)) {
	Write-Host $member.name
}
Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
