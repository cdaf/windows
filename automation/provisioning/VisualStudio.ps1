$scriptName = 'VisualStudio.ps1'
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$initFile = $args[0]
if ($initFile) {
    Write-Host "[$scriptName] initFile : $initFile"
} else {
    Write-Host "[$scriptName] initFile not supplied, halt!"
    exit 100
}

$media = $args[1]
if ($media) {
    Write-Host "[$scriptName] media    : $media"
} else {
	$media = 'D:\*'
    Write-Host "[$scriptName] media    : $media (default)"
}

$installDir = [Environment]::GetEnvironmentVariable('TEMP', 'Machine') + '\IDEinstall'
if (!( Test-Path $installDir )) {
    Write-Host "[$scriptName] Create install directory ($installDir)"
	mkdir $installDir
}
Write-Host "[$scriptName] Copy-Item -Path $media -Destination $installDir -Recurse -Force"
Copy-Item -Path $media -Destination $installDir -Recurse -Force

$filePath = "$installDir\Setup\setup.exe"
try {
	$argList = @("/unattendfile", "$initFile")
	Write-Host "[$scriptName] Start-Process -FilePath $filePath -ArgumentList $argList -PassThru -Wait"
	$proc = Start-Process -FilePath $filePath -ArgumentList $argList -PassThru -Wait
} catch {
	Write-Host "[$scriptName] $media Install Exception : $_" -ForegroundColor Red
	exit 200
}

Write-Host
Write-Host "[$scriptName] ---------- stop ----------"
