Param (
	[string]$boxname,
	[string]$hypervisor,
	[string]$diskDir,
	[string]$emailTo,
	[string]$smtpServer,
	[string]$emailFrom,
	[string]$skipTest
)
$scriptName = 'AtlasPackage.ps1'
cmd /c "exit 0"

# Use executeIgnoreExit to only trap powershell errors, use executeExpression to trap all errors, including $LASTEXITCODE
function execute ($expression) {
	$error.clear()
	Write-Host "[$(date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "`$? = $?"; emailAndExit 1050 }
	} catch { echo $_.Exception|format-list -force; emailAndExit 1051 }
    if ( $error[0] ) { Write-Host "`$error[0] = $error"; emailAndExit 1052 }
}

function executeExpression ($expression) {
	execute $expression
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
    	Write-Host "[$scriptName] ERROR! Exiting with `$LASTEXITCODE = $LASTEXITCODE" -foregroundcolor "red";
    	emailAndExit $LASTEXITCODE
	}
}

function executeIgnoreExit ($expression) {
	execute $expression
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] Warning `$LASTEXITCODE = $LASTEXITCODE" -foregroundcolor "yellow"; cmd /c "exit 0" }
}

# Exception Handling email sending
function emailAndExit ($exitCode) {
	if ($smtpServer) {
		Send-MailMessage -To "$emailTo" -From "$emailFrom" -Subject "[$scriptName][$hypervisor] ERROR $exitCode" -SmtpServer "$smtpServer"
	}
	exit $exitCode
}

# Informational email notification 
function emailProgress ($subject) {
	if ($smtpServer) {
		Send-MailMessage -To "$emailTo" -From "$emailFrom" -Subject "[$scriptName][$hypervisor] $subject" -SmtpServer "$smtpServer"
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
		$diskDir = "D:\VMs\$boxName"
	    Write-Host "[$scriptName] diskDir     : $diskDir (default)"
	} else {
	    Write-Host "[$scriptName] diskDir     : (not specified, only required if VirtualBox)"
    }
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

if ($emailFrom) {
    Write-Host "[$scriptName] emailFrom   : $emailFrom"
} else {
    Write-Host "[$scriptName] emailFrom   : (not specified, email will not be attempted)"
}

if ($skipTest) {
    Write-Host "[$scriptName] skipTest    : $skipTest"
} else {
	$skipTest = 'no'
    Write-Host "[$scriptName] skipTest    : $skipTest (default)"
}

$imageLog = "$(pwd)\atlasPackage_${hypervisor}.txt"
if (Test-Path "$imageLog") {
    Write-Host "`n[$scriptName] Logfile exists ($imageLog), delete for new run."
	Remove-Item "$imageLog"
}

Write-Host "`n[$scriptName] Prepare Temporary build directory"
$buildDir = "${boxName}_${hypervisor}"
if (Test-Path "$buildDir") {
	executeExpression "Remove-Item $buildDir -Recurse -Force"
}

$packageFile = "${buildDir}.box"
emailProgress "packaging ${packageFile}, logging to ${imageLog}."
Write-Host "packaging ${packageFile}, logging to ${imageLog}."

executeExpression "Write-Host 'Create working directory $(mkdir $buildDir)'"
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

	if ( $boxname -Match "Windows" ) { # This tells Vagrant to use WinRM instead of SSH
		executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'https://raw.githubusercontent.com/cdaf/windows/master/samples/vagrant-box/Vagrantfile`', `"$PWD\Vagrantfile`")"
	} else {
		executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'https://raw.githubusercontent.com/cdaf/linux/master/samples/vagrant-box/Vagrantfile`', `"$PWD\Vagrantfile`")"
	}
	Write-Host "`n[$scriptName] List the contents of the package Vagrantfile"
	executeExpression "cat Vagrantfile"
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

	if ( $boxname -Match "Windows" ) { # This tells Vagrant to use WinRM instead of SSH
		executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'https://raw.githubusercontent.com/cdaf/windows/master/samples/vagrant-box/Vagrantfile`', `"$PWD\Vagrantfile`")"
		$filename = "Vagrantfile"
		$token = '#hyper-v: '
		$value = ''
		(Get-Content $fileName | ForEach-Object { $_ -replace [regex]::Escape($token), "$value" } ) | Set-Content $fileName
	} else {
		executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'https://raw.githubusercontent.com/cdaf/linux/master/samples/vagrant-box/Vagrantfile`', `"$PWD\Vagrantfile`")"
	}
	Write-Host "`n[$scriptName] List the contents of the package Vagrantfile"
	executeExpression "cat Vagrantfile"

    $versionTest = cmd /c bsdtar --version 2`>`&1 ; cmd /c "exit 0" # Reset LASTEXITCODE
    if ($versionTest -like '*not recognized*') {
    	Write-Host "`n[$scriptName] BSD Tar not installed, compress with tar"
    	Write-Host "`n[$scriptName]   tar cvzf ../$packageFile ./*"
	    $versionTest = cmd /c tar --version 2`>`&1
	    if ($versionTest -like '*not recognized*') {
	    	Write-Host "`n[$scriptName]   TAR not installed, (this is included in bash tools, see Git for Windows) exit with LASTEXITCODE $LASTEXITCODE"; exit $LASTEXITCODE
	    }
		Write-Host "$logFile" "[$scriptName] tar cvzf ../$packageFile ./*"
        $proc = Start-Process -FilePath 'tar' -ArgumentList "cvzf ../$packageFile ./*" -PassThru -Wait -NoNewWindow
        if ( $proc.ExitCode -ne 0 ) {
	        Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
            exit $proc.ExitCode
        }
    } else {
    	Write-Host "`n[$scriptName] Use BSD Tar ($versionTest) with maximum compression (lzma)"
    	Write-Host "`n[$scriptName]   bsdtar --lzma -cvf ../$packageFile *"
		Write-Host "$logFile" "[$scriptName] bsdtar --lzma -cvf ../$packageFile *"
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

Write-Host "`n[$scriptName] Add the box to the local cache"
$testDir = 'packageTest'
if (Test-Path "$testDir ") {
	executeExpression "Remove-Item $testDir -Recurse -Force"
}
executeIgnoreExit "vagrant box remove cdaf/$boxName --all --force" # ignore error if none exist

Write-Host "`n[$scriptName] vagrant box add cdaf/$boxName $packageFile --force"
Write-Host "$logFile" "[$scriptName] vagrant box add cdaf/$boxName $packageFile --force"
$proc = Start-Process -FilePath 'vagrant' -ArgumentList "box add cdaf/$boxName $packageFile --force" -PassThru -Wait -NoNewWindow
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

Write-Host "$logFile" "[$scriptName] Return to workspace"
executeExpression "cd .."

if ($skipTest -eq 'yes') {
	Write-Host "`n[$scriptName] skipTest is ${skipTest}, tests not attempted."
} else {

	if ( $boxname -Match "Windows" ) { # This tells Vagrant to use WinRM instead of SSH
		executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'https://raw.githubusercontent.com/cdaf/windows/master/samples/vagrant-test/Vagrantfile`', `"$PWD\Vagrantfile`")"
	} else {
		executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'https://raw.githubusercontent.com/cdaf/linux/master/samples/vagrant-test/Vagrantfile`', `"$PWD\Vagrantfile`")"
	}

	Write-Host "`n[$scriptName] Log vagrant file contents"
	executeExpression "cat .\Vagrantfile"

	Write-Host "$logFile" "[$scriptName] Set the box to use for testing"
	execute "`$env:OVERRIDE_IMAGE = `"cdaf/$boxname`""

	Write-Host "$logFile" "[$scriptName] vagrant up"
	$proc = Start-Process -FilePath 'vagrant' -ArgumentList 'up' -PassThru -Wait -NoNewWindow
	if ( $proc.ExitCode -ne 0 ) {
		Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
	    exit $proc.ExitCode
	}

    Write-Host "`n[$scriptName] vagrant destroy -f"
	Write-Host "$logFile" "[$scriptName] vagrant destroy -f"
    $proc = Start-Process -FilePath 'vagrant' -ArgumentList 'destroy -f' -PassThru -Wait -NoNewWindow
    if ( $proc.ExitCode -ne 0 ) {
	    Write-Host "`n[$scriptName] WARNING Laster `$LASTEXITCODE = $($proc.ExitCode)`n"
        cmd /c "exit 0"
    }

    Write-Host "`n[$scriptName] Clean-up Vagrant Temporary files"
    executeExpression "Remove-Item -Recurse $env:USERPROFILE\.vagrant.d\tmp\*"
}

Write-Host "$logFile" "[$scriptName] vagrant box list"
$proc = Start-Process -FilePath 'vagrant' -ArgumentList 'box list' -PassThru -Wait -NoNewWindow
if ( $proc.ExitCode -ne 0 ) {
	Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
    exit $proc.ExitCode
}

emailProgress "Final notifcation, package of ${packageFile} complete"

Write-Host "`n[$scriptName] ---------- stop ----------"
