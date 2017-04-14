Param (
  [string]$boxname,
  [string]$hypervisor,
  [string]$diskDir,
  [string]$emailTo,
  [string]$smtpServer
)
$scriptName = 'AtlasPackage.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function emailAndExit ($exitCode) {
	if ($smtpServer) {
		executeExpression "Send-MailMessage -To `"$emailTo`" -From `'no-reply@cdaf.info`' -Subject `"$scriptName [$hypervisor] ERROR $exitCode`" -SmtpServer `"$smtpServer`""
	}
	exit $exitCode
}

function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	Add-Content "$imageLog" "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; Add-Content "$imageLog" "[$scriptName] `$? = $?"; emailAndExit 1 }
	} catch { echo $_.Exception|format-list -force; Add-Content "$imageLog" "$_.Exception|format-list"; emailAndExit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; Add-Content "$imageLog" "[$scriptName] `$error[0] = $error"; emailAndExit 3 }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($boxname) {
    Write-Host "[$scriptName] boxname    : $boxname"
} else {
	$boxname = 'WindowsServer'
    Write-Host "[$scriptName] boxname    : (not specified, defaulted to $boxname)"
}

if ($hypervisor) {
    Write-Host "[$scriptName] hypervisor : $hypervisor"
} else {
	$hypervisor = 'virtualbox'
    Write-Host "[$scriptName] hypervisor : (not specified, defaulted to $hypervisor)"
}

if ($diskDir) {
    Write-Host "[$scriptName] diskDir    : $diskDir"
} else {
    Write-Host "[$scriptName] diskDir    : (not specified, required if VirtualBox)"
}

if ($emailTo) {
    Write-Host "[$scriptName] emailTo    : $emailTo"
} else {
    Write-Host "[$scriptName] emailTo    : (not specified, email will not be attempted)"
}

if ($smtpServer) {
    Write-Host "[$scriptName] smtpServer : $smtpServer"
} else {
    Write-Host "[$scriptName] smtpServer : (not specified, email will not be attempted)"
}

$imageLog = 'imageLog.txt'
if (Test-Path "$imageLog") {
    Write-Host "`n[$scriptName] Logfile exists ($imageLog), delete for new run."
	executeExpression "Remove-Item `"$imageLog`""
}
if ($smtpServer) {
	executeExpression "Send-MailMessage -To `"$emailTo`" -From `'no-reply@cdaf.info`' -Subject `"$scriptName [$hypervisor] starting, logging to $imageLog`" -SmtpServer `"$smtpServer`""
}

Write-Host "`n[$scriptName] Prepare Temporary build directory"
$buildDir = 'tempBuildDir'
if (Test-Path "$buildDir") {
	executeExpression "Remove-Item $buildDir -Recurse -Force"
}
executeExpression "mkdir $buildDir"
executeExpression "cd $buildDir"

if ($hypervisor = 'virtualbox') {

	Write-Host "`n[$scriptName] Export VirtualBox VM"
	executeExpression "& `"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe`" modifyhd `"${diskDir}\${boxName}\${boxName}.vdi`" --compact"

	executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'http://cdaf.io/static/app/downloads/Vagrantfile`', `"$PWD\Vagrantfile`")"
	executeExpression "vagrant package --base $boxName --output $packageFile --vagrantfile Vagrantfile"
	executeExpression "vagrant box add $boxName $packageFile --force"

} else {

	Write-Host "`n[$scriptName] Export Hyper-V VM"
	$packageFile = $boxname + '.box'
	executeExpression "Export-VM -Name $boxName -Path ."
	
	if (Test-Path $packageFile) {
		executeExpression "Remove-Item $packageFile"
	}
	Write-Host "`n[$scriptName] Compress VM into .box format"
	executeExpression "cd $boxName"
	executeExpression "Remove-Item Snapshots -Force -Recurse"
	if (Test-Path metadata.json ) {
		executeExpression "Remove-Item metadata.json"
	} 
	Add-Content metadata.json "{`n  ""provider"": ""hyperv""`n}"
	executeExpression "cat metadata.json"
	executeExpression "tar cvzf ../$packageFile ./*"
	  
	Write-Host "`n[$scriptName] Remove VM export files"
	executeExpression "cd.."
	executeExpression "Remove-Item $boxname -Force -Recurse"
}

Write-Host "`n[$scriptName] Initialise and start"
$testDir = 'packageTest'
if (Test-Path "$testDir ") {
	executeExpression "Remove-Item $testDir  -Recurse -Force"
}
executeExpression "mkdir $testDir"
executeExpression "cd $testDir"
executeExpression "vagrant box add $boxName ../$packageFile --force"
executeExpression "vagrant init $boxName"
executeExpression "vagrant up"


Write-Host "`n[$scriptName] Cleanup after test"
executeExpression "vagrant destroy -f"
executeExpression "cd .."
executeExpression "Remove-Item $testDir -Force -Recurse"
executeExpression "vagrant box remove $boxName"

if ($smtpServer) {
	executeExpression "Send-MailMessage -To `"$emailTo`" -From `'no-reply@cdaf.info`' -Subject `"$scriptName [$hypervisor] final notifcation, package test complete`" -SmtpServer `"$smtpServer`""
}

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0