Param (
	[string]$boxname,
	[string]$hypervisor,
	[string]$diskDir,
	[string]$emailTo,
	[string]$smtpServer,
	[string]$skipTest,
	[string]$destroy
)
$scriptName = 'AtlasPackage.ps1'
cmd /c "exit 0"

# Write to standard out and file
function writeLog ($message) {
	Write-Host "[$scriptName] $message"
	Add-Content $imageLog "[$scriptName] $message"
}

# Use executeIgnoreExit to only trap exceptions, use executeExpression to trap all errors ($LASTEXITCODE is global)
function execute ($expression) {
	$error.clear()
	writeLog " > $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { writeLog "`$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { writeLog "`$error[0] = $error"; exit 3 }
}

function executeExpression ($expression) {
	execute $expression
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] ERROR! Exiting with `$LASTEXITCODE = $LASTEXITCODE" -foregroundcolor "red"; exit $LASTEXITCODE }
}

function executeIgnoreExit ($expression) {
	execute $expression
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] Warning `$LASTEXITCODE = $LASTEXITCODE" -foregroundcolor "yellow"; cmd /c "exit 0" }
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

if ($skipTest) {
    Write-Host "[$scriptName] skipTest    : $skipTest"
} else {
	$skipTest = 'no'
    Write-Host "[$scriptName] skipTest    : $skipTest (default)"
}

if ($destroy) {
    Write-Host "[$scriptName] destroy     : $destroy"
} else {
	$destroy = 'yes'
    Write-Host "[$scriptName] destroy     : $destroy (default)"
}

$imageLog = "$(pwd)\atlasPackage_${hypervisor}.txt"
if (Test-Path "$imageLog") {
    Write-Host "`n[$scriptName] Logfile exists ($imageLog), delete for new run."
	Remove-Item "$imageLog"
}

writeLog "`n[$scriptName] Prepare Temporary build directory"
$buildDir = "${boxName}_${hypervisor}"
if (Test-Path "$buildDir") {
	executeExpression "Remove-Item $buildDir -Recurse -Force"
}

$packageFile = "${buildDir}.box"
emailProgress "packaging ${packageFile}, logging to ${imageLog}."
writeLog "packaging ${packageFile}, logging to ${imageLog}."

executeExpression "mkdir $buildDir"
executeExpression "cd $buildDir"

if ($hypervisor -eq 'virtualbox') {

	$diskPath = "${diskDir}\${boxName}.vdi"
	writeLog "`n[$scriptName] Export VirtualBox VM"
	if (Test-Path "$diskPath") {
		executeExpression "& `"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe`" modifyhd `"$diskPath`" --compact"
	} else {
		writeLog "`n[$scriptName] Disk ($diskPath) not found! Exiting with lastExitCode 200"
		emailAndExit 200
	}

	executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'http://cdaf.io/static/app/downloads/Vagrantfile`', `"$PWD\Vagrantfile`")"
	executeExpression "vagrant package --base $boxName --output $packageFile --vagrantfile Vagrantfile"

} else {

	writeLog "`n[$scriptName] Export Hyper-V VM"
	executeExpression "Export-VM -Name $boxName -Path ."
	
	if (Test-Path $packageFile) {
		executeExpression "Remove-Item $packageFile"
	}
	writeLog "`n[$scriptName] Compress VM into .box format"
	executeExpression "cd $boxName"
	executeExpression "Remove-Item Snapshots -Force -Recurse"
	if (Test-Path metadata.json ) {
		executeExpression "Remove-Item metadata.json"
	} 
	Add-Content metadata.json "{`n  ""provider"": ""hyperv""`n}"
	executeExpression "cat metadata.json"

    $versionTest = cmd /c bsdtar --version 2`>`&1 ; cmd /c "exit 0" # Reset LASTEXITCODE
    if ($versionTest -like '*not recognized*') {
    	writeLog "`n[$scriptName] BSD Tar not installed, compress with tar"
    	writeLog "`n[$scriptName]   tar cvzf ../$packageFile ./*"
	    $versionTest = cmd /c tar --version 2`>`&1
	    if ($versionTest -like '*not recognized*') {
	    	writeLog "`n[$scriptName]   TAR not installed, (this is included in bash tools, see Git for Windows) exit with LASTEXITCODE $LASTEXITCODE"; exit $LASTEXITCODE
	    }
		writeLog "$logFile" "[$scriptName] tar cvzf ../$packageFile ./*"
        $proc = Start-Process -FilePath 'tar' -ArgumentList "cvzf ../$packageFile ./*" -PassThru -Wait -NoNewWindow
        if ( $proc.ExitCode -ne 0 ) {
	        writeLog "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
            exit $proc.ExitCode
        }
    } else {
    	writeLog "`n[$scriptName] Use BSD Tar ($versionTest) with maximum compression (lzma)"
    	writeLog "`n[$scriptName]   bsdtar --lzma -cvf ../$packageFile *"
		writeLog "$logFile" "[$scriptName] bsdtar --lzma -cvf ../$packageFile *"
        $proc = Start-Process -FilePath 'bsdtar' -ArgumentList "--lzma -cvf ../$packageFile *" -PassThru -Wait -NoNewWindow
        if ( $proc.ExitCode -ne 0 ) {
	        writeLog "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
            exit $proc.ExitCode
        }
    }
    
	writeLog "`n[$scriptName] Remove VM export files"
	executeExpression "cd.."
	executeExpression "Remove-Item $boxname -Force -Recurse"

}

if ($skipTest -eq 'yes') {
	writeLog "`n[$scriptName] skipTest is $[skipTest}, tests not attempted."
} else {
	writeLog "`n[$scriptName] Initialise and start"
	$testDir = 'packageTest'
	if (Test-Path "$testDir ") {
		executeExpression "Remove-Item $testDir  -Recurse -Force"
	}
	executeIgnoreExit "vagrant box remove cdaf/$boxName --all" # ignore error if none exist
	
	writeLog "`n[$scriptName] vagrant box add cdaf/$boxName $packageFile --force"
	writeLog "$logFile" "[$scriptName] vagrant box add cdaf/$boxName $packageFile --force"
	$proc = Start-Process -FilePath 'vagrant' -ArgumentList "box add cdaf/$boxName $packageFile --force" -PassThru -Wait -NoNewWindow
	if ( $proc.ExitCode -ne 0 ) {
		writeLog "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
	    exit $proc.ExitCode
	}
	
	writeLog "$logFile" "[$scriptName] Return to workspace and list the Vagrantfile before testing"
	executeExpression "cd .."
	executeExpression "cat .\Vagrantfile"
	
	writeLog "$logFile" "[$scriptName] Set the box to use for testing"
	execute "`$env:OVERRIDE_IMAGE = `"cdaf/$boxname`""
	
	writeLog "$logFile" "[$scriptName] vagrant up target"
	$proc = Start-Process -FilePath 'vagrant' -ArgumentList 'up target' -PassThru -Wait -NoNewWindow
	if ( $proc.ExitCode -ne 0 ) {
		writeLog "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
	    exit $proc.ExitCode
	}
	
	writeLog "$logFile" "[$scriptName] vagrant box list"
	$proc = Start-Process -FilePath 'vagrant' -ArgumentList 'box list' -PassThru -Wait -NoNewWindow
	if ( $proc.ExitCode -ne 0 ) {
		writeLog "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
	    exit $proc.ExitCode
	}
}  

if ($destroy -eq 'yes') { 
	writeLog "`n[$scriptName] Cleanup after test"
    writeLog "`n[$scriptName] vagrant destroy -f"
	writeLog "$logFile" "[$scriptName] vagrant destroy -f"
    $proc = Start-Process -FilePath 'vagrant' -ArgumentList 'destroy -f' -PassThru -Wait -NoNewWindow
    if ( $proc.ExitCode -ne 0 ) {
	    writeLog "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
        exit $proc.ExitCode
    }

    writeLog "`n[$scriptName] Clean-up Vagrant Temporary files"
    executeExpression "Remove-Item -Recurse $env:USERPROFILE\.vagrant.d\tmp\*"
}

emailProgress "Final notifcation, package of ${packageFile} complete"

writeLog "`n[$scriptName] ---------- stop ----------"
