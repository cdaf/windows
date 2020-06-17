$scriptName = 'installCDAF.ps1'
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

function main () {
	Write-Host "`n[$scriptName] --- start ---"
	if ($env:CDAF_PATH) {
		$installPath = $env:CDAF_PATH
	    Write-Host "[$scriptName] installPath : $installPath (from `$env:CDAF_PATH)"
	} else {
		$installPath = '~/.cdaf'
	    Write-Host "[$scriptName] installPath : $installPath (default)"
	}
	if ( Test-Path "$env:temp\windows-master" ) { 
		executeExpression "Remove-Item -Recurse '$env:temp\windows-master'"
	}
	if ( Test-Path "$env:temp\cdaf.zip" ) { 
		executeExpression "Remove-Item -Recurse '$env:temp\cdaf.zip'"
	}
	if ( Test-Path "$installPath" ) { 
		executeExpression "Remove-Item -Recurse '$installPath'"
	}
	if ( $env:http_proxy ) {
		executeExpression "[system.net.webrequest]::defaultwebproxy = New-Object system.net.webproxy('$env:http_proxy')"
	} else {
		executeExpression '(New-Object System.Net.WebClient).Proxy.Credentials =[System.Net.CredentialCache]::DefaultNetworkCredentials' 
	}
	executeExpression '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12'
	executeExpression "(New-Object System.Net.WebClient).DownloadFile('https://codeload.github.com/cdaf/windows/zip/master', '$env:temp\cdaf.zip')"
	executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
	executeExpression "[System.IO.Compression.ZipFile]::ExtractToDirectory('$env:temp\cdaf.zip', '$env:temp')"
	executeExpression "Move-Item '$env:temp\windows-master\automation\' '$installPath'"
	executeExpression "$installPath/remote/capabilities.ps1"
	executeExpression "Remove-Item -Recurse '$env:temp\windows-master'"
	executeExpression "Remove-Item '$env:temp\cdaf.zip'"

	Write-Host "`n[$scriptName] Installed to $installPath"
	Write-Host "`n[$scriptName] --- end ---"
}

main
