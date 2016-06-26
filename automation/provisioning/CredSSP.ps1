function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
}

$scriptName     = 'CredSSP.ps1'
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
		executeExpression 'Enable-WSManCredSSP -Role client -DelegateComputer * -Force'
		executeExpression "New-ItemProperty -Path `'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation`' -Name `'AllowFreshCredentialsWhenNTLMOnly`' -Value 1 -PropertyType Dword -Force"
		executeExpression "New-Item -Path `'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation`' -Name `'AllowFreshCredentialsWhenNTLMOnly`' -Value `'Default Value`' -Force"
		executeExpression "New-ItemProperty -Path `'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly`' -Name `'1`' -PropertyType `'String`' -Value 'wsman/*'"
#		executeExpression "Set-ItemProperty -path `'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp\PolicyDefaults\AllowFreshCredentialsDomain`' -Name `'WSMan`' -Value `'WSMAN/*`'"  
	}
	'server' {
		executeExpression 'Enable-WSManCredSSP -Role server -Force'
	}
    default {
	    Write-Host "[$scriptName] Installtype ($Installtype) not supported, choices are $installChoices"
    }
}

Write-Host "[$scriptName] ---------- stop -----------"
Write-Host