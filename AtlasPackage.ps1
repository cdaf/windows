Param (
	[string]$boxname,
	[string]$hypervisor,
	[string]$diskDir,
	[string]$vagrantfile,
	[string]$emailTo,
	[string]$smtpServer,
	[string]$destroy
)
$scriptName = 'AtlasPackage.ps1'


# Use executeIgnoreExit to only trap exceptions, use executeExpression to trap all errors ($LASTEXITCODE is global)
function executeExpression ($expression) {
	execute $expression
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] ERROR! Exiting with `$LASTEXITCODE = $LASTEXITCODE" -foregroundcolor "red"; exit $LASTEXITCODE }
}

function executeIgnoreExit ($expression) {
	execute $expression
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] Warning `$LASTEXITCODE = $LASTEXITCODE" -foregroundcolor "yellow"; cmd /c "exit 0" }
}

function execute ($expression) {
	$error.clear()
	Write-Host "[$scriptName] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
}

# Exception Handling email sending
function emailAndExit ($exitCode) {
	if ($smtpServer) {
		Send-MailMessage -To "$emailTo" -From 'no-reply@cdaf.info' -Subject "[$scriptName][$hypervisor] ERROR $exitCode" -SmtpServer "$smtpServer"
	}
	exit $exitCode
}

# Informational email notification 
function emailProgress ($subject) {
	if ($smtpServer) {
		Send-MailMessage -To "$emailTo" -From 'no-reply@cdaf.info' -Subject "[$scriptName][$hypervisor] $subject" -SmtpServer "$smtpServer"
	}
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($boxname) {
    Write-Host "[$scriptName] boxname     : $boxname"
} else {
	$boxname = 'WindowsServerStandard'
    Write-Host "[$scriptName] boxname     : (not specified, defaulted to $boxname)"
}

if ($hypervisor) {
    Write-Host "[$scriptName] hypervisor  : $hypervisor"
} else {
	$hypervisor = 'virtualbox'
    Write-Host "[$scriptName] hypervisor  : (not specified, defaulted to $hypervisor)"
}

if ($diskDir) {
    Write-Host "[$scriptName] diskDir     : $diskDir"
} else {
	if ( $hypervisor -eq 'virtualbox' ) {
	    Write-Host "[$scriptName] diskDir required for VirtualBox! Exit with LASTEXITCODE 103"; exit 103
	} else {
	    Write-Host "[$scriptName] diskDir     : (not specified, only required if VirtualBox)"
    }
}

if ($vagrantfile) {
    Write-Host "[$scriptName] vagrantfile : $vagrantfile"
} else {
    Write-Host "[$scriptName] vagrantfile : (not specified, will use default for testing)"
}

if ($emailTo) {
    Write-Host "[$scriptName] emailTo     : $emailTo"
} else {
    Write-Host "[$scriptName] emailTo     : (not specified, email will not be attempted)"
}

if ($smtpServer) {
    Write-Host "[$scriptName] smtpServer  : $smtpServer"
} else {
    Write-Host "[$scriptName] smtpServer  : (not specified, email will not be attempted)"
}

if ($destroy) {
    Write-Host "[$scriptName] destroy     : $destroy"
} else {
	$destroy = 'yes'
    Write-Host "[$scriptName] destroy     : $destroy (default)"
}

$logFile = "$(pwd)\atlasPackage_${hypervisor}.txt"
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
emailProgress "packaging ${packageFile}, logging to ${logFile}."

executeExpression "mkdir $buildDir"
executeExpression "cd $buildDir"

if ($hypervisor -eq 'virtualbox') {

	$diskPath = "${diskDir}\${boxName}.vdi"
	Write-Host "`n[$scriptName] Export VirtualBox VM"
	if (Test-Path "$diskPath") {
		executeExpression "& `"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe`" modifyhd `"$diskPath`" --compact"
	} else {
		Write-Host "`n[$scriptName] Disk ($diskPath) not found! Exiting with lastExitCode 200"
		emailAndExit 200
	}

	executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'http://cdaf.io/static/app/downloads/Vagrantfile`', `"$PWD\Vagrantfile`")"
	executeExpression "vagrant package --base $boxName --output $packageFile --vagrantfile Vagrantfile"

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

    $versionTest = cmd /c bsdtar --version 2`>`&1 ; cmd /c "exit 0" # Reset LASTEXITCODE
    if ($versionTest -like '*not recognized*') {
    	Write-Host "`n[$scriptName] BSD Tar not installed, compress with tar"
    	Write-Host "`n[$scriptName]   tar cvzf ../$packageFile ./*"
	    $versionTest = cmd /c tar --version 2`>`&1
	    if ($versionTest -like '*not recognized*') {
	    	Write-Host "`n[$scriptName]   TAR not installed, (this is included in bash tools, see Git for Windows) exit with LASTEXITCODE $LASTEXITCODE"; exit $LASTEXITCODE
	    }
		Add-Content "$logFile" "[$scriptName] tar cvzf ../$packageFile ./*"
        $proc = Start-Process -FilePath 'tar' -ArgumentList "cvzf ../$packageFile ./*" -PassThru -Wait -NoNewWindow
        if ( $proc.ExitCode -ne 0 ) {
	        Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
            exit $proc.ExitCode
        }
    } else {
    	Write-Host "`n[$scriptName] Use BSD Tar ($versionTest) with maximum compression (lzma)"
    	Write-Host "`n[$scriptName]   bsdtar --lzma -cvf ../$packageFile *"
		Add-Content "$logFile" "[$scriptName] bsdtar --lzma -cvf ../$packageFile *"
        $proc = Start-Process -FilePath 'bsdtar' -ArgumentList "--lzma -cvf ../$packageFile *" -PassThru -Wait -NoNewWindow
        if ( $proc.ExitCode -ne 0 ) {
	        Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
            exit $proc.ExitCode
        }
    }
    
	Write-Host "`n[$scriptName] Remove VM export files"
	executeExpression "cd.."
	executeExpression "Remove-Item $boxname -Force -Recurse"

}

Write-Host "`n[$scriptName] Initialise and start"
$testDir = 'packageTest'
if (Test-Path "$testDir ") {
	executeExpression "Remove-Item $testDir  -Recurse -Force"
}
executeIgnoreExit "vagrant box remove cdaf/$boxName --box-version 0" # Remove any local (non-Atlas) images, ignore error if not exist

Write-Host "`n[$scriptName] vagrant box add cdaf/$boxName $packageFile --force"
Add-Content "$logFile" "[$scriptName] vagrant box add cdaf/$boxName $packageFile --force"
$proc = Start-Process -FilePath 'vagrant' -ArgumentList "box add cdaf/$boxName $packageFile --force" -PassThru -Wait -NoNewWindow
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

executeExpression "cd .."
if ( $vagrantfile ) {
	Write-Host "`n[$scriptName] Override default Vagrantfile with $vagrantfile"
	executeExpression "mv Vagrantfile Vagrantfiledefault"
	executeExpression "mv $vagrantfile Vagrantfile"
}

if ( $hypervisor -eq 'virtualbox' ) {

	Write-Host "`n[$scriptName][virtualbox] vagrant up"
	Add-Content "$logFile" "[$scriptName][virtualbox] vagrant up"
	$proc = Start-Process -FilePath 'vagrant' -ArgumentList 'up' -PassThru -Wait -NoNewWindow
	if ( $proc.ExitCode -ne 0 ) {
		Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
	    exit $proc.ExitCode
	}

} else {

	# Complete scenario not supported in Vagrantfile for Hyper-V, so only test Target 
	Write-Host "`n[$scriptName][hyperv] vagrant up target --no-provision"
	Add-Content "$logFile" "[$scriptName][hyperv] vagrant up target --no-provision"
	$proc = Start-Process -FilePath 'vagrant' -ArgumentList 'up target --no-provision' -PassThru -Wait -NoNewWindow
	if ( $proc.ExitCode -ne 0 ) {
		Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
	    exit $proc.ExitCode
	}

}

Add-Content "$logFile" "[$scriptName] vagrant box list"
$proc = Start-Process -FilePath 'vagrant' -ArgumentList 'box list' -PassThru -Wait -NoNewWindow
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

if ($destroy -eq 'yes') { 
	Write-Host "`n[$scriptName] Cleanup after test"
    Write-Host "`n[$scriptName] vagrant destroy -f"
	Add-Content "$logFile" "[$scriptName] vagrant destroy -f"
    $proc = Start-Process -FilePath 'vagrant' -ArgumentList 'destroy -f' -PassThru -Wait -NoNewWindow
    if ( $proc.ExitCode -ne 0 ) {
	    Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
        exit $proc.ExitCode
    }

    Write-Host "`n[$scriptName] Clean-up Vagrant Temporary files"
    executeExpression "Remove-Item -Recurse $env:USERPROFILE\.vagrant.d\tmp\*"
}

if ( $vagrantfile ) {
	Write-Host "`n[$scriptName] Reinstate default Vagrantfile"
	executeExpression "mv Vagrantfile $vagrantfile"
	executeExpression "mv Vagrantfiledefault Vagrantfile"
}

emailProgress "Final notifcation, package of ${packageFile} complete"

Write-Host "`n[$scriptName] ---------- stop ----------"
