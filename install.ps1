Param (
	[string]$version
)

$scriptName = 'install.ps1'
cmd /c "exit 0"
$Error.Clear()

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	Write-Host "[$(Get-Date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; $error ; exit 1111 }
	} catch { Write-Output $_.Exception|format-list -force; $error ; exit 1112 }
    if ( $LASTEXITCODE ) {
    	if ( $LASTEXITCODE -ne 0 ) {
			Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE " -ForegroundColor Red ; $error ; exit $LASTEXITCODE
		} else {
			if ( $error ) {
				Write-Host "[$scriptName][WARN] `$Error[] populated but `$LASTEXITCODE = $LASTEXITCODE error follows... $Error`n" -ForegroundColor Yellow
				$Error.Clear()
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName][WARN] `$Error[] = $Error" -ForegroundColor Yellow
			$Error.Clear()
		}
	}
}

Write-Host "`n[$scriptName] --- start ---"
if ( $version ) {
    Write-Host "[$scriptName]   version     : $version"
} else {
    Write-Host "[$scriptName]   version     : (not passed, use edge)"
}

if ( $env:CDAF_INSTALL_PATH ) {
	$installPath = $env:CDAF_INSTALL_PATH
    Write-Host "[$scriptName]   installPath : $installPath (from `$env:CDAF_INSTALL_PATH)"
} else {
	$installPath = "$(pwd)\automation"
    Write-Host "[$scriptName]   installPath : $installPath (default)"
}

if ( Test-Path $installPath ) {
	executeExpression "Remove-Item -Recurse '$installPath'"
}

if ( $version ) {

	if ( Test-Path "$(pwd)\automation" ) {
		executeExpression "Remove-Item -Recurse '$(pwd)\automation'"
	}
	executeExpression "iwr -useb http://cdaf.io/static/app/downloads/WU-CDAF-${version}.zip -outfile WU-CDAF-${version}.zip"
	executeExpression "Add-Type -AssemblyName System.IO.Compression.FileSystem"
	executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory('$(pwd)\WU-CDAF-${version}.zip', '$(pwd)')"
	executeExpression "Move-Item '$(pwd)\automation' '${installPath}'"
	executeExpression "Remove-Item '$(pwd)\WU-CDAF-${version}.zip'"

} else {

	if ( Test-Path "$(pwd)\windows-master" ) {
		executeExpression "Remove-Item -Recurse '$(pwd)\windows-master'"
	}
	executeExpression "iwr -useb https://codeload.github.com/cdaf/windows/zip/refs/heads/master -outfile cdaf.zip"
	executeExpression "Add-Type -AssemblyName System.IO.Compression.FileSystem"
	executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory('$(pwd)\cdaf.zip', '$(pwd)')"
	executeExpression "Move-Item '.\windows-master\automation\' '${installPath}'"
	executeExpression "Remove-Item -Recurse '$(pwd)\windows-master'"
	executeExpression "Remove-Item '$(pwd)\cdaf.zip'"
	
}

if ( $env:CDAF_INSTALL_PATH ) {
	executeExpression "${installPath}\addPath.ps1 '${installPath}\automation\provisioning'"
	executeExpression "${installPath}\addPath.ps1 '${installPath}\remote\provisioning'"
	executeExpression "${installPath}\addPath.ps1 '${installPath}\automation'"
}

executeExpression "${installPath}\remote\capabilities.ps1"

Write-Host "`n[$scriptName] --- end ---"
