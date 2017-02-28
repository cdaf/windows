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

$scriptName = 'loadVSenv.ps1'
Write-Host "[$scriptName] ---------- start ----------"
Write-Host
$version = $args[0]
if ($version) {
    Write-Host "[$scriptName] version   : $version"
} else {
	$version = '2015'
    Write-Host "[$scriptName] version   : not supplied, defaulted to $version"
}

# from http://stackoverflow.com/questions/2124753/how-i-can-use-powershell-with-the-visual-studio-command-prompt
switch ($version) {
	2017 {
		pushd "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\Tools"
		cmd /c "VsDevCmd.bat&set" |
		foreach {
		  if ($_ -match "=") {
		    Write-Host "[$scriptName]   $_";$v = $_.split("="); set-item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
		  }
		}
		popd
		Write-Host "`nVisual Studio 2017 Command Prompt variables set." -ForegroundColor Yellow
	}
	2015 {
		pushd 'C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\Tools'    
		cmd /c "vsvars32.bat&set" |
		foreach {
		  if ($_ -match "=") {
		    Write-Host "[$scriptName]   $_";$v = $_.split("="); set-item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
		  }
		}
		popd
		write-host "`nVisual Studio 2015 Command Prompt variables set." -ForegroundColor Yellow
	}
    default {
		pushd 'c:\Program Files (x86)\Microsoft Visual Studio 10.0\VC'
		cmd /c "vcvarsall.bat&set" |
		foreach {
		  if ($_ -match "=") {
		    Write-Host "[$scriptName]   $_";$v = $_.split("="); set-item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
		  }
		}
		popd
		write-host "`nVisual Studio 2010 Command Prompt variables set." -ForegroundColor Yellow
    }
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
