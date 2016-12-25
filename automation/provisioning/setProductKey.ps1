$scriptName = 'setProductKey.ps1'
Write-Host
Write-Host "[$scriptName] Install Windows Product key in preparation for activation"
Write-Host
Write-Host "[$scriptName] ---------- start ----------"
$fileFile = $args[0]
if ($fileFile) {
    Write-Host "[$scriptName] fileFile : $fileFile"
} else {
	$fileFile = 'C:\.provision\productkey.txt'
    Write-Host "[$scriptName] fileFile : $fileFile (default)"
}

Write-Host
if (Test-Path $fileFile ) {
	Write-Host "[$scriptName] $fileFile found"
} else {
	Write-Host "[$scriptName] $fileFile not found!"
	exit 200
}
$key = [IO.File]::ReadAllText($fileFile)
$computer = gc env:computername
$service = get-wmiObject -query "select * from SoftwareLicensingService" -computername $computer

Write-Host "[$scriptName] Install key and refresh status"
$service.InstallProductKey($key)
$service.RefreshLicenseStatus()

Write-Host
Write-Host "[$scriptName] ---------- stop -----------"
Write-Host