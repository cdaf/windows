Param (
	[string]$action,
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
	Write-Host "[$(Get-date)] $expression"
	try {
		Invoke-Expression $expression
	    if(!$?) { Write-Host "`$? = $?"; emailAndExit 1050 $expression }
	} catch { Write-Output $_.Exception|format-list -force; emailAndExit 1051 $expression }
    if ( $error[0] ) { Write-Host "`$error[0] = $error"; emailAndExit 1052 $expression }
}

function executeExpression ($expression) {
	execute $expression
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) {
    	Write-Host "[$scriptName] ERROR! Exiting with `$LASTEXITCODE = $LASTEXITCODE" -foregroundcolor "red";
    	emailAndExit $LASTEXITCODE $expression
	}
}

function executeIgnoreExit ($expression) {
	execute $expression
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] Warning `$LASTEXITCODE = $LASTEXITCODE" -foregroundcolor "yellow"; cmd /c "exit 0" }
}

# Exception Handling email sending
function emailAndExit ($exitCode, $message) {
	if ( $message ) {
		Write-Host "$message"
	}
	if ($smtpServer) {
		Send-MailMessage -To "$emailTo" -From "$emailFrom" -Subject "[$scriptName][$hypervisor] $message Exit Code $exitCode" -SmtpServer "$smtpServer"
	}
	exit $exitCode
}

# Informational email notification 
function emailProgress ($subject) {
	if ($smtpServer) {
		Send-MailMessage -To "$emailTo" -From "$emailFrom" -Subject "[$scriptName][$hypervisor] $subject" -SmtpServer "$smtpServer"
	}
}

function MAKDIR ($itemPath) { 
	# If directory already exists, just report, otherwise create the directory and report
		if ( Test-Path $itemPath ) {
			if (Test-Path $itemPath -PathType "Container") {
				write-host "[$scriptName (MAKDIR)] $itemPath exists"
			} else {
				Remove-Item $itemPath -Recurse -Force
				if(!$?) { taskFailure "[$scriptName (MAKDIR)] Remove-Item $itemPath -Recurse -Force" }
				mkdir $itemPath > $null
				if(!$?) { taskFailure "[$scriptName (MAKDIR)] (replace) $itemPath Creation failed" }
			}	
		} else {
			mkdir $itemPath > $null
			if(!$?) { taskFailure "[$scriptName (MAKDIR)] $itemPath Creation failed" }
		}
	}
	
Write-Host "`n[$scriptName] ---------- start ----------"
if ($action) {
    Write-Host "[$scriptName] action      : $action"
} else {
    Write-Host "[$scriptName] action not specified, Select Package or Clone"; exit 1101
}

if ($boxname) {
    Write-Host "[$scriptName] boxname     : $boxname"
} else {
    Write-Host "[$scriptName] boxname not specified!"; exit 1102
}

if ($hypervisor) {
    Write-Host "[$scriptName] hypervisor  : $hypervisor"
} else {
    Write-Host "[$scriptName] hypervisor, select hyperv or virtualbox"; exit 1103
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

if ( $env:http_proxy ) {
    Write-Host "[$scriptName] http_proxy  : $env:http_proxy"
    executeExpression "[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('$env:http_proxy')"
}

Write-Host "`n[$scriptName] Set TLS to version 1.2 or higher"
executeExpression "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls11,Tls12'"

$imageLog = "$(Get-Location)\atlasPackage_${hypervisor}.txt"
if (Test-Path "$imageLog") {
    Write-Host "`n[$scriptName] Logfile exists ($imageLog), delete for new run."
	Remove-Item "$imageLog"
}

if ($action -eq 'Clone') {
	if ($hypervisor -eq 'virtualbox') {
		Write-Host "`n[$scriptName] Ensure ${diskDir} exists ..."
		MAKDIR ${diskDir}

		$clonedhd = "D:\Hyper-V\$boxName.vhdx"
		Write-Host "`n[$scriptName] Copy Hyper-V disk to VirtualBox..."
		executeExpression "Copy-Item Z:\vHDD\$boxName.vhdx $clonedhd"

		$diskPath = "${diskDir}\${boxName}.vdi"
		Write-Host "`n[$scriptName] Disk ($diskPath) Import VirtualBox Disk image from Hyper-V, ..."
		executeExpression "& 'C:\Program Files\Oracle\Virtualbox\VBoxmanage.exe' clonehd '$clonedhd' '$diskDir\$boxName.vdi' --format vdi"
		emailProgress "VirtualBox Dick Clone Complete"
	} else {
		emailAndExit 200 "Perform all actions on VirtualBox Host!"
	}
		
} else {
	
	Write-Host "`n[$scriptName] Prepare Temporary build directory"
	executeExpression "cd ~"
	if (Test-Path "boxbuilder") {
		executeExpression "Remove-Item boxbuilder -Recurse -Force"
	}
	Write-Host "`n[$scriptName] Create boxbuilder directory ..."
	MAKDIR "boxbuilder"
	executeExpression "cd boxbuilder"

	$buildDir = "${boxName}_${hypervisor}"
	if (Test-Path "$buildDir") {
		executeExpression "Remove-Item $buildDir -Recurse -Force"
	}
	Write-Host "Create working directory $buildDir"
	executeExpression "mkdir $buildDir"
	executeExpression "cd $buildDir"
	
	$packageFile = "${buildDir}.box"
	emailProgress "packaging ${packageFile}, logging to ${imageLog}."
	Write-Host "packaging ${packageFile}, logging to ${imageLog}."
	
	if ($hypervisor -eq 'virtualbox') {
	
		$diskPath = "${diskDir}\${boxName}.vdi"
		Write-Host "Hypervisor $hypervisor using diskPath: $diskPath"
		if ( $diskPath ) {
			if ( Test-Path $diskPath ) {
				Write-Host "`n[$scriptName] Export VirtualBox VM"
				executeExpression "& `"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe`" modifyhd `"$diskPath`" --compact"
			} else {
				emailAndExit 200 "Disk ($diskPath) not found!"
			}
		} else {
			emailAndExit 200 "`$diskPath not defined!"
		}
	
		if ( $boxname -Match "Windows" ) { # This tells Vagrant to use WinRM instead of SSH
			executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'https://raw.githubusercontent.com/cdaf/windows/master/samples/vagrant-box/Vagrantfile`', `"$PWD\Vagrantfile`")"
		} else {
			executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'https://raw.githubusercontent.com/cdaf/linux/master/samples/vagrant-box/Vagrantfile`', `"$PWD\Vagrantfile`")"
		}
		
		$filename = "Vagrantfile"
		$token = '#virtbox: '
		$value = ''
		(Get-Content $fileName | ForEach-Object { $_ -replace [regex]::Escape($token), "$value" } ) | Set-Content $fileName
	
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
		} else {
			executeExpression "(New-Object System.Net.WebClient).DownloadFile(`'https://raw.githubusercontent.com/cdaf/linux/master/samples/vagrant-box/Vagrantfile`', `"$PWD\Vagrantfile`")"
		}
		$filename = "Vagrantfile"
		$token = '#hyper-v: '
		$value = ''
		(Get-Content $fileName | ForEach-Object { $_ -replace [regex]::Escape($token), "$value" } ) | Set-Content $fileName
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
			emailAndExit ($proc.ExitCode) "Vagrant up failed!"
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
		emailAndExit ($proc.ExitCode) "vagrant box list failed!"
	}
	
	emailProgress "Final notification, package of ${packageFile} complete"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
