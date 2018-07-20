Param (
	[string]$install
)

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

$scriptName = 'base.ps1'
Write-Host "[$scriptName] Install components using Chocolatey.`n"
Write-Host "[$scriptName] ---------- start ----------"
if ($install) {
    Write-Host "[$scriptName] install    : $install"
} else {
    Write-Host "[$scriptName] Package to install not supplied, exiting with LASTEXITCODE 4"; exit 4 
}

if ($mediaDir) {
    Write-Host "[$scriptName] mediaDir   : $mediaDir"
} else {
	$mediaDir = '/.provision'
    Write-Host "[$scriptName] mediaDir   : $mediaDir (default)"
}

$versionTest = cmd /c choco --version 2`>`&1
if ($versionTest -like '*not recognized*') {
	Write-Host "`n[$scriptName] Chocolatey not installed, installing ..."
	cmd /c "exit 0"
	if (!( Test-Path $mediaDir )) {
		Write-Host "[$scriptName] mkdir $mediaDir"
		Write-Host "[$scriptName]   $(mkdir $mediaDir) created"
	}
	
	Write-Host
	$file = 'install.ps1'
	$fullpath = $mediaDir + '\' + $file
	if ( Test-Path $fullpath ) {
		Write-Host "[$scriptName] $fullpath exists, download not required"
	} else {
	
		$uri = 'https://chocolatey.org/' + $file
		Write-Host "[$scriptName] $file does not exist in $mediaDir, listing contents"
		try {
			Get-ChildItem $mediaDir | Format-Table name
		    if(!$?) { $fullpath = listAndContinue }
		} catch { $fullpath = listAndContinue }

		Write-Host "[$scriptName] Attempt download"
		executeExpression "(New-Object System.Net.WebClient).DownloadFile('$uri', '$fullpath')"
	}
	
	try {
		$argList = @("$fullpath")
		Write-Host "[$scriptName] Start-Process -FilePath 'powershell' -ArgumentList $argList -PassThru -Wait"
		$proc = Start-Process -FilePath 'powershell' -ArgumentList $argList -PassThru -Wait
	} catch {
		Write-Host "[$scriptName] $file Install Exception : $_" -ForegroundColor Red
		exit 200
	}
	
	# Reload the path (without logging off and back on)
	$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

	$versionTest = cmd /c choco --version 2`>`&1
	if ($versionTest -like '*not recognized*') {
		Write-Host "[$scriptName] Chocolatey install has failed, exiting!"
		exit # that should retain the exit code from the version test itself
	}

}
Write-Host "[$scriptName] Chocolatey : $versionTest"

Write-Host
executeExpression "choco install -y $install --no-progress --fail-on-standard-error"

Write-Host "`n[$scriptName] Reload the path`n"
executeExpression '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")'

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0
