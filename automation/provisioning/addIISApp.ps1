function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	# Execute expression and trap powershell exceptions
	try {
	    Invoke-Expression $expression
	    if(!$?) {
			Write-Host; Write-Host "[$scriptName] Expression failed without an exception thrown. Exit with code 1."; Write-Host 
			exit 1
		}
	} catch {
		Write-Host; Write-Host "[$scriptName] Expression threw exception. Exit with code 2, exception message follows ..."; Write-Host 
		Write-Host "[$scriptName] $_"; Write-Host 
		exit 2
	}
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
