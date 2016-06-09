function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
}

$scriptName = 'addIISApp.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$app = $args[0]
if ($app) {
    Write-Host "[$scriptName] app          : $app"
} else {
    Write-Host "[$scriptName] app no supplied"
    exit 100
}

$physicalPath = $args[1]
if ($physicalPath) {
    Write-Host "[$scriptName] physicalPath : $physicalPath"
} else {
	$physicalPath = 'c:\inetpub\' + $app
    Write-Host "[$scriptName] physicalPath : $physicalPath (default)"
}

$site = $args[2]
if ($site) {
    Write-Host "[$scriptName] site         : $site"
} else {
	$site = 'Default Web Site'
    Write-Host "[$scriptName] site         : $site (default)"
}

executeExpression 'import-module WebAdministration'
executeExpression "New-Item `'IIS:\Sites\$site\$app`' -PhysicalPath `'$physicalPath`' -Type Application"

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
