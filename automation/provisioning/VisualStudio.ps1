function executeExpression ($expression) {
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { exit 1 }
	} catch { exit 2 }
    if ( $error[0] ) { exit 3 }
}

$scriptName = 'VisualStudio.ps1'
# VS2015 Enterprise   http://download.microsoft.com/download/1/2/1/1211d9dd-b504-47f2-90f2-20cb8b44e096/vs2015.2.ent_enu.iso
# VS2013 Professional http://download.microsoft.com/download/F/2/E/F2EFF589-F7D7-478E-B3AB-15F412DA7DEB/vs2013.5_pro_enu.iso
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$version = $args[0]
if ($version) {
    Write-Host "[$scriptName] version  : $version"
} else {
	$version = '2010'
    Write-Host "[$scriptName] version  : $version (default)"
}

$media = $args[1]
if ($media) {
    Write-Host "[$scriptName] media    : $media"
} else {
	$media = 'D:\'
    Write-Host "[$scriptName] media    : $media (default)"
}

$initFile = $args[2]
if ($initFile) {
    Write-Host "[$scriptName] initFile : $initFile"
} else {
    Write-Host "[$scriptName] initFile not supplied (only required for 2010)"
}

if ($env:interactive) {
    Write-Host "[$scriptName] env:interactive : $env:interactive, run in current window"
    $sessionControl = '-PassThru -Wait -NoNewWindow'
} else {
    $sessionControl = '-PassThru -Wait'
}

if ($version -eq '2010' ) {

	if (!($initFile)) {
	   Write-Host "[$scriptName] initFile not supplied, required for 2010, exiting"
	}	

	# cannot install from a read only source, so copy the source to temp
	$media = $media + '*'
	$installDir = [Environment]::GetEnvironmentVariable('TEMP', 'Machine') + '\IDEinstall'
	if (!( Test-Path $installDir )) {
	    Write-Host "[$scriptName] Create install directory ($installDir)"
		executeExpression "mkdir $installDir"
	}
	executeExpression "Copy-Item -Path $media -Destination $installDir -Recurse -Force"
	
	$filePath = "$installDir\Setup\setup.exe"
	try {
		$argList = @("/unattendfile", "$initFile")
		executeExpression "$proc = Start-Process -FilePath $filePath -ArgumentList $argList $sessionControl"
	} catch {
		Write-Host "[$scriptName] $media Install Exception : $_" -ForegroundColor Red
		exit 200
	}

} else {

	$executable = Get-ChildItem d:\ -Filter *.exe
	$argList = @("/Q", "/S", "/LOG $env:TEMP\$executable.name.log", "/NoWeb", "/NoRefresh", "/Full")
	executeExpression "`$proc = Start-Process -FilePath `"$media$executable`" -ArgumentList `'$argList`' $sessionControl"

}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
