$scriptName     = 'CredSSP-Client.ps1'
$installChoices = 'client or server' 
Write-Host
Write-Host "[$scriptName] Credential Delegation, required on client and server"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$Installtype = $args[0]
if ($Installtype) {
    Write-Host "[$scriptName] Installtype : $Installtype (choices $installChoices)"
} else {
	$Installtype = 'server'
    Write-Host "[$scriptName] Installtype : $Installtype (default, choices $installChoices)"
}

switch ($Installtype) {
	'client' {
		Write-Host "[$scriptName] Enable-WSManCredSSP -Role client -DelegateComputer * -Force"
		Enable-WSManCredSSP -Role client -DelegateComputer * -Force
	}
	'server' {
		Write-Host "[CredSSP-Server.ps1] Enable-WSManCredSSP -Role server -Force"
		Enable-WSManCredSSP -Role server -Force
	}
    default {
	    Write-Host "[$scriptName] Installtype ($Installtype) not supported, choices are $installChoices"
    }
}

Write-Host "[$scriptName] ---------- stop -----------"
Write-Host