$scriptName = 'VisualStudioSP.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$version = $args[0]
if ($version) {
    Write-Host "[$scriptName] version     : $version"
} else {
	$version = '2010'
    Write-Host "[$scriptName] version     : $version (Default)"
}

$servicePack = $args[1]
if ($servicePack) {
    Write-Host "[$scriptName] servicePack : $servicePack"
} else {
	$servicePack = '1'
    Write-Host "[$scriptName] servicePack : $servicePack (Default)"
}

$media = $args[2]
if ($media) {
    Write-Host "[$scriptName] media       : $media"
} else {
	$media = 'D:\'
    Write-Host "[$scriptName] media       : $media (default)"
}

$filePath = "$media\setup.exe"
try {
	$argList = @("/q", "/norestart")
	Write-Host "[$scriptName] Start-Process -FilePath $filePath -ArgumentList $argList -PassThru -Wait"
	$proc = Start-Process -FilePath $filePath -ArgumentList $argList -PassThru -Wait
} catch {
	Write-Host "[$scriptName] $media Install Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host "[$scriptName]"
Write-Host "[$scriptName] To verify SP applied, check Visual Studio UI"
Write-Host "[$scriptName]"
Write-Host "[$scriptName] Microsoft Visual Studio 2010"
Write-Host "[$scriptName] Version 10.0.40219.1 SP1Rel"
Write-Host "[$scriptName] Microsoft .NET Framework"
Write-Host "[$scriptName] Version 4.0.30319 SP1Rel"
Write-Host "[$scriptName]"
Write-Host "[$scriptName] ---------- stop ----------"
