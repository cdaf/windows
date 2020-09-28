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
				Write-Host "[$scriptName][WARN] $Error array populated by `$LASTEXITCODE = $LASTEXITCODE, $error[] = $error`n" -ForegroundColor Yellow
				$error.clear()
			}
		} 
	} else {
	    if ( $error ) {
			Write-Host "[$scriptName][WARN] $Error array populated but LASTEXITCODE not set, $error[] = $error`n" -ForegroundColor Yellow
			$error.clear()
		}
	}
}

$scriptName = 'dev.ps1'

Write-Host "`n[$scriptName] ---------- start ----------"
if ( $env:http_proxy ) {
    executeExpression "[system.net.webrequest]::defaultwebproxy = New-Object system.net.webproxy('$env:http_proxy')"
} else {
    executeExpression '(New-Object System.Net.WebClient).Proxy.Credentials =[System.Net.CredentialCache]::DefaultNetworkCredentials' 
}

executeExpression  "cd ~"
executeExpression '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12'
executeExpression  ". { iwr -useb http://cdaf.io/static/app/downloads/cdaf.ps1 } | iex"

executeExpression  "~\automation\provisioning\base.ps1 'adoptopenjdk8 maven'"
executeExpression  "~\automation\provisioning\base.ps1 eclipse -version 4.16"
executeExpression  "~\automation\provisioning\base.ps1 'nuget.commandline azure-cli visualstudio2019enterprise vscode'"

executeExpression  "~\automation\provisioning\base.ps1 'nodejs.install python'
executeExpression  "~\automation\provisioning\base.ps1 ruby -version 2.7.0.1"
executeExpression  "~\automation\provisioning\base.ps1 'msys2 sqlite'"
executeExpression  "~\automation\provisioning\base.ps1 'hugo git svn vnc-viewer putty winscp postman insomnia-rest-api-client'"
executeExpression  "~\automation\provisioning\base.ps1 'pdk citrix-receiver zoom microsoft-edge'"
executeExpression  "~\automation\provisioning\base.ps1 'googlechrome' -checksum ignore"

executeExpression  "~\automation\provisioning\base.ps1 'vagrant' -autoReboot yes"

Write-Host "`n[$scriptName] ---------- stop ----------"
