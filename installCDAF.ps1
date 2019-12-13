Param (
	[string]$installPath
)

$scriptName = 'installCDAF.ps1'

cmd /c "exit 0"

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { Write-Host $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

function main ($installPath) {
	Write-Host "`n[$scriptName] --- start ---"
	if ($installPath) {
	    Write-Host "[$scriptName] installPath : $installPath"
	} else {
		$installPath = '~/.cdaf'
	    Write-Host "[$scriptName] installPath : $installPath (default)"
	}
	if ( $env:http_proxy ) {
		executeExpression "[system.net.webrequest]::defaultwebproxy = New-Object system.net.webproxy('$env:http_proxy')"
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

main $installPath
