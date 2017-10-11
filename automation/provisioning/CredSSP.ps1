# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

# Test for registry property 
function testProperty ($path, $property) {
	if (Test-Path $path) {
		$key = Get-Item $path
		if ($key.GetValue($property, $null) -ne $null) {
			$True
		} else {
			$False
		}
	} else {
		$False
	}
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
		$ntlmFreshPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly'
		if ( testProperty $ntlmFreshPath '1') {
			executeExpression "Remove-ItemProperty -Path `'$ntlmFreshPath`' -Name `'1`'"
		}
		executeExpression 'Enable-WSManCredSSP -Role client -DelegateComputer * -Force'

		Write-Host "[$scriptName] For `"tripple hop`" scenario, desktop (off domain) --[PS]--> buildserver (on domain) --[PS]--> app (on domain) --[SQL]--> database (on domain)"
	    Write-Host "[$scriptName]   Setting for : desktop (off domain) --[PS]--> buildserver (on domain)"
		Write-Host
		$lmPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
		if ( Test-Path -Path $lmPath ) {
		    Write-Host "[$scriptName] $lmPath exists"
			Write-Host
		} else {
			executeExpression "New-Item -Path `'HKLM:\SOFTWARE\Policies\Microsoft\Windows`' -Name `'CredentialsDelegation`' -Value `'Default Value`' -Force"
		}
		
		if ( testProperty $lmPath 'AllowFreshCredentialsWhenNTLMOnly') {
			Write-Host "[$scriptName] AllowFreshCredentialsWhenNTLMOnly current value $((Get-ItemProperty -Path "$lmPath" -Name 'AllowFreshCredentialsWhenNTLMOnly').AllowFreshCredentialsWhenNTLMOnly)"
			executeExpression "Set-ItemProperty -Path `'$lmPath`' -Name `'AllowFreshCredentialsWhenNTLMOnly`' -Value 1"
		} else {
			executeExpression "New-ItemProperty -Path `'$lmPath`' -Name `'AllowFreshCredentialsWhenNTLMOnly`' -Value 1 -PropertyType Dword"
		}
		
		if ( Test-Path -Path $ntlmFreshPath ) {
		    Write-Host "[$scriptName] $ntlmFreshPath exists"
			Write-Host
		} else {
			executeExpression "New-Item -Path `'$lmPath`' -Name `'AllowFreshCredentialsWhenNTLMOnly`' -Value `'Default Value`'"
		}
		# Safe to execute without force becuase this has been removed before enabling windows remote managmenet, if it existed		
		executeExpression "New-ItemProperty -Path `'$ntlmFreshPath`' -Name `'1`' -PropertyType `'String`' -Value 'wsman/*'"
		
	    Write-Host "[$scriptName]   Setting for : buildserver (on domain) --[PS]--> app (on domain)"
		Write-Host
		executeExpression "New-ItemProperty -path `'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp\PolicyDefaults\AllowFreshCredentialsDomain`' -Name `'WSMan`' -Value `'WSMAN/*`' -Force"
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