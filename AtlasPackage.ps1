Param (
  [string]$boxname,
  [string]$hypervisor,
  [string]$diskDir,
  [string]$emailTo,
  [string]$smtpServer,
  [string]$destroy
)
$scriptName = 'AtlasPackage.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function emailAndExit ($exitCode) {
	if ($smtpServer) {
		executeExpression "Send-MailMessage -To `"$emailTo`" -From `'no-reply@cdaf.info`' -Subject `"[$scriptName][$hypervisor] ERROR $exitCode`" -SmtpServer `"$smtpServer`""
	}
	exit $exitCode
}

function executeExpression ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	Add-Content "$logFile" "[$scriptName] $expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; Add-Content "$logFile" "[$scriptName] `$? = $?"; emailAndExit 1 }
	} catch { echo $_.Exception|format-list -force; Add-Content "$logFile" "$_.Exception|format-list"; emailAndExit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; Add-Content "$logFile" "[$scriptName] `$error[0] = $error"; emailAndExit 3 }
    if ( $lastExitCode -ne 0 ) { Write-Host "[$scriptName] `$lastExitCode = $lastExitCode "; exit $lastExitCode }
    return $output
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($boxname) {
    Write-Host "[$scriptName] boxname    : $boxname"
} else {
	$boxname = 'WindowsServerStandard'
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

if ($destroy) {
    Write-Host "[$scriptName] destroy : $destroy"
} else {
	$destroy = 'yes'
    Write-Host "[$scriptName] destroy : $destroy (default)"
}

$logFile = "atlasPackage_${hypervisor}.txt"
if (Test-Path "$logFile") {
    Write-Host "`n[$scriptName] Logfile exists ($logFile), delete for new run."
	executeExpression "Remove-Item `"$logFile`""
}

Write-Host "`n[$scriptName] Prepare Temporary build directory"
$buildDir = "${boxName}_${hypervisor}"
if (Test-Path "$buildDir") {
	executeExpression "Remove-Item $buildDir -Recurse -Force"
}

$packageFile = "${buildDir}.box"
if ($smtpServer) {
	executeExpression "Send-MailMessage -To `"$emailTo`" -From `'no-reply@cdaf.info`' -Subject `"[$scriptName] packaging ${packageFile}, logging to ${logFile}.`" -SmtpServer `"$smtpServer`""
}

executeExpression "mkdir $buildDir"
executeExpression "cd $buildDir"

if ($hypervisor -eq 'virtualbox') {

	$diskPath = "${diskDir}\${boxName}\WindowsServerCore.vdi"
	Write-Host "`n[$scriptName] Export VirtualBox VM"
	if (Test-Path "$diskPath") {
		executeExpression "& `"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe`" modifyhd `"$diskPath`" --compact"
	} else {
		Write-Host "`n[$scriptName] Disk ($diskPath) not found! Exiting with lastExitCode 200"
		emailAndExit 200
	}

	executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'http://cdaf.io/static/app/downloads/Vagrantfile`', `"$PWD\Vagrantfile`")"
	executeExpression "vagrant package --base $boxName --output $packageFile --vagrantfile Vagrantfile"
	executeExpression "vagrant box add $boxName $packageFile --force"

} else {

	Write-Host "`n[$scriptName] Export Hyper-V VM"
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
executeExpression "vagrant box remove cdaf/$boxName --box-version 0" # Remove any local (non-Atlas) images
executeExpression "vagrant box add cdaf/$boxName $packageFile --force"
executeExpression "cd .."
if (!($boxname -eq 'WindowsServerStandard')) {
	Write-Host "`n[$scriptName] Override default Vagrantfile"
	executeExpression "mv Vagrantfile Vagrantfiledefault"
	executeExpression "mv VagrantfileDC Vagrantfile"
}
executeExpression "vagrant up"

if ($destroy -eq 'yes') { 
	Write-Host "`n[$scriptName] Cleanup after test"
	executeExpression "vagrant destroy -f"
}

if (!($boxname -eq 'WindowsServerStandard')) {
	Write-Host "`n[$scriptName] Reinstate default Vagrantfile"
	executeExpression "mv Vagrantfile VagrantfileDC"
	executeExpression "mv Vagrantfiledefault Vagrantfile"
}

if ($smtpServer) {
	executeExpression "Send-MailMessage -To `"$emailTo`" -From `'no-reply@cdaf.info`' -Subject `"[$scriptName] Final notifcation, package of ${packageFile} complete`" -SmtpServer `"$smtpServer`""
}

Write-Host "`n[$scriptName] ---------- stop ----------"
exit 0